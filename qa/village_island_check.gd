class_name VillageIslandCheck
extends RefCounted
## An island village judged as one (VTER-ISLAND-FILL, docs/VILLAGE_TERRAIN.md
## "The island fill"): a ring quay inside the shore, a spine from landing to
## landing, every building on dry ground, and the island built out to its edge.
##
##   ring     the ring's arcs join end to end: every arc's two ends are an end
##            of another arc (and the spine crosses it at two of them)
##   spine    the through road runs from one landing at the shore to another,
##            as far apart as the island is long
##   dry      no lot, building or common is on the ground's water
##   fill     the island is BUILT OUT: the share of its dry ground within
##            REACH_M of a building is at least REACH_MIN -- "edge to edge",
##            the village reaches the water from the middle of the island
##            (`reach_share`, on the caller's own grid, so the same measure
##            reads a plan sited any other way). The shore's own share within
##            NEAR_M of a building (`shore_fronted`) is reported.
##
## Stats: ring_arcs, ring_gap_m (the ring's mean distance inside the shore),
## shore_m, shore_fronted, island_reach, buildings, lots_dry.

## The shoreline is sampled this often, and a sample is fronted by a building
## this near.
const SHORE_STEP_M := 6.0
const NEAR_M := 25.0
## The island's dry ground is read on this lattice, and counts as reached
## within REACH_M of a building; REACH_MIN of it must be.
const LATTICE_M := 8.0
const REACH_M := 30.0
const REACH_MIN := 0.85
const RING_JOIN_M := 0.6
const LANDINGS_APART := 0.6

var failures: Array[String] = []
var stats := {}


func check(plan: VillagePlan) -> Dictionary:
	failures.clear()
	stats = {}
	if plan.island.is_empty() or plan.shoreline.size() < 8 or plan.roads.size() < 3:
		failures.append("island: the plan is not an island village (no island, shoreline or ring)")
		return _report()
	_ring(plan)
	_spine(plan)
	_dry(plan)
	_fill(plan)
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures.duplicate(), "stats": stats}


func _ring(plan: VillagePlan) -> void:
	var arcs: Array[int] = []
	for r in range(1, plan.roads.size()):
		if plan.roads[r]["class"] == &"street":
			arcs.append(r)
	stats["ring_arcs"] = arcs.size()
	if arcs.size() < 4:
		failures.append("ring: %d arcs; a ring quay is at least four" % arcs.size())
		return
	for r in arcs:
		var pts: PackedVector2Array = plan.roads[r]["points"]
		for end in [pts[0], pts[pts.size() - 1]]:
			var joined := false
			for q in arcs:
				if q == r:
					continue
				var other: PackedVector2Array = plan.roads[q]["points"]
				if end.distance_to(other[0]) <= RING_JOIN_M or end.distance_to(other[other.size() - 1]) <= RING_JOIN_M:
					joined = true
					break
			if not joined:
				failures.append("ring: arc %d ends at %v on no other arc" % [r, end])
	var gap := 0.0
	var n := 0
	for r in arcs:
		for p in plan.roads[r]["points"]:
			gap += _distance_to_ring(plan.shoreline, p)
			n += 1
	stats["ring_gap_m"] = gap / float(maxi(n, 1))


func _spine(plan: VillagePlan) -> void:
	var through: Array[int] = plan.roads_of_class(&"through")
	if through.size() != 1:
		failures.append("spine: %d through roads; an island has one" % through.size())
		return
	var pts: PackedVector2Array = plan.roads[through[0]]["points"]
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var long_side: float = maxf(plan.site.size.x, plan.site.size.y)
	for end in [a, b]:
		if not VillageMeasure.on_boundary(plan.site, end) and not VillageGroundWater.on_shore(plan, end, 6.5):
			failures.append("spine: an end at %v is not at the shore" % end)
	if a.distance_to(b) < LANDINGS_APART * long_side:
		failures.append("spine: its landings are %.0f m apart, the island is %.0f m long" % [a.distance_to(b), long_side])


func _dry(plan: VillagePlan) -> void:
	var wet := 0
	var g: VillageTerrain = plan.ground
	for lot in plan.lots:
		if float(g.under(lot["poly"])["dry_share"]) < 1.0:
			wet += 1
	for b in plan.buildings:
		if float(g.under(Placement.world_rect(b["placement"], b["transform"], true))["dry_share"]) < 1.0:
			wet += 1
	for c in plan.commons:
		if float(g.under(c["poly"])["dry_share"]) < 1.0:
			wet += 1
	stats["lots_dry"] = plan.lots.size() - wet
	stats["buildings"] = plan.buildings.size()
	if wet > 0:
		failures.append("dry: %d lots, buildings or commons stand on the water" % wet)


func _fill(plan: VillagePlan) -> void:
	var reach: float = reach_share(plan, plan.spec.terrain)
	stats["island_reach"] = reach
	stats["shore_fronted"] = fronted_share(plan)
	stats["shore_m"] = float(_along(plan.shoreline, SHORE_STEP_M).size()) * SHORE_STEP_M
	if reach < REACH_MIN:
		failures.append("fill: %.0f %% of the island is within %.0f m of a building, wants %.0f %%"
			% [reach * 100.0, REACH_M, REACH_MIN * 100.0])


## The share of the island's dry ground (the caller's `terrain`, on a LATTICE_M
## lattice over the island found by VillageIslandForm.describe) within REACH_M
## of a building of `plan`, whatever frame the plan was sited in.
static func reach_share(plan: VillagePlan, terrain: VillageTerrain) -> float:
	var d := VillageIslandForm.describe(terrain)
	if d.is_empty() or plan.ground == null:
		return 0.0
	var wl: float = terrain.water_level_m + VillageGroundWater.FREEBOARD_M
	var feet: Array[PackedVector2Array] = []
	for b in plan.buildings:
		var foot := PackedVector2Array()
		for p in VillageMeasure.footprint_poly(b):
			foot.append(plan.ground.to_parent(p))
		feet.append(foot)
	var box: Rect2 = d["bounds"]
	var dry := 0
	var reached := 0
	var y := box.position.y + LATTICE_M * 0.5
	while y < box.end.y:
		var x := box.position.x + LATTICE_M * 0.5
		while x < box.end.x:
			var p := Vector2(x, y)
			if terrain.height_at(p) > wl:
				dry += 1
				for f in feet:
					if VillageMeasure.point_to_poly(p, f) <= REACH_M:
						reached += 1
						break
			x += LATTICE_M
		y += LATTICE_M
	return float(reached) / float(maxi(dry, 1))


## The share of the shoreline (the plan's) with a building within NEAR_M.
static func fronted_share(plan: VillagePlan) -> float:
	var feet: Array[PackedVector2Array] = []
	for b in plan.buildings:
		feet.append(VillageMeasure.footprint_poly(b))
	var samples := _along(plan.shoreline, SHORE_STEP_M)
	var fronted := 0
	for s in samples:
		for f in feet:
			if VillageMeasure.point_to_poly(s, f) <= NEAR_M:
				fronted += 1
				break
	return float(fronted) / float(maxi(samples.size(), 1))


## Points every `step` metres round the closed outline `ring`.
static func _along(ring: PackedVector2Array, step: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var carry := 0.0
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		var seg := a.distance_to(b)
		var d := carry
		while d < seg:
			out.append(a.lerp(b, d / maxf(seg, 1e-9)))
			d += step
		carry = d - seg
	return out


static func _distance_to_ring(ring: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		best = minf(best, p.distance_to(c))
	return best
