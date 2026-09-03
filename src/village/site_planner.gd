class_name VillageSitePlanner
extends RefCounted
## The first planner: the ground, the through road, the common, and the
## streets and lanes of the `street` and `green` forms. VILLAGES §3, §5, §12.
##
## Order matters and is the whole of §2: the through road is laid FIRST
## (a gentle polyline, never a straight line across the site), then the
## common ON it, then the landmark slot is RESERVED -- before any house lot
## exists, because everything else is arranged around it -- and only then the
## streets and lanes the form asks for. Nothing here cuts a house lot; that
## is the lot planner's job (VIL-004), and it starts from `plan.landmark_site`
## already being taken.
##
## Everything is a pure function of the spec's seven inputs: the planner
## reads `spec` and never writes to it (the purity rule), and every random
## draw comes from a `RandomNumberGenerator` seeded by name from `spec.seed`.

## §5's road table. `width` is the carriageway, `verge` the strip either side
## that nothing may stand on; `surface` is indexed by wealth band (poor,
## middling, rich).
const ROAD_CLASSES := {
	&"through": {"width": 6.0, "verge": 1.5, "surface": ["dirt", "gravel", "cobble"]},
	&"street": {"width": 4.0, "verge": 1.0, "surface": ["dirt", "dirt", "cobble"]},
	&"lane": {"width": 2.5, "verge": 0.5, "surface": ["dirt", "dirt", "dirt"]},
	&"path": {"width": 1.2, "verge": 0.0, "surface": ["trodden", "trodden", "stones"]},
	&"track": {"width": 3.0, "verge": 0.0, "surface": ["dirt", "dirt", "dirt"]},
}

## The forms this planner knows. Everything else is VIL-006 and later.
const FORMS_SUPPORTED: Array[StringName] = [&"street", &"green"]

const SITE_MIN_SIDE := 90.0     ## below this a 6 m road, a common and a landmark do not fit
const SITE_MAX_SIDE := 400.0    ## §9.1 "not a city"
const TARGET_DENSITY := 0.16    ## built area / site area, mid of §9.1's 0.06 - 0.30 band
const HOUSE_FOOTPRINT := 70.0   ## rough, only for sizing the ground

## The through road is sampled every ~10 m, which is short enough that the
## bend rules (`<= 25 deg per 20 m`, `radius >= 3 x width`) are measured on
## the geometry the plan actually carries rather than on a smoothing of it.
const THROUGH_SAMPLE_M := 10.0
const THROUGH_MIN_SAMPLES := 9
## Amplitudes of the two harmonics of the through road, as a fraction of its
## length. Kept small on purpose: with a half-wave of amplitude a1 and a full
## wave of a2 over length L, the tightest radius is about L / (PI^2 (a1+4a2)),
## which for these numbers is >= 0.9 L -- far inside both bend rules -- while
## still bending several metres off the chord, so the road is never straight.
const BEND_A1 := Vector2(0.035, 0.050)
const BEND_A2 := Vector2(0.005, 0.015)
const MIN_BOW_M := 2.0          ## a road at least this far off its own chord is not "straight across"

const COMMON_MIN_AREA := 150.0
const HAMLET_COMMON_AREA := 30.0
const HAMLET_POPULATION := 25
const WELL_PLOT_SIDE := 5.6     ## the hamlet's common shrunk to the well: 31.4 m^2
const COMMON_ROAD_GAP := 1.5    ## clear metres between the road's verge and the common

const GREEN_MIN_W := 18.0
const GREEN_MIN_H := 12.0
const GREEN_SIDE_CLEAR := 4.0   ## from the green's edge to the ring street's centreline

const LANDMARK_AREA := 240.0    ## a church and its churchyard
const LANDMARK_AREA_SMALL := 144.0  ## a shrine's, where the population has not earned a church
const LANDMARK_GAP := 3.0

const LANE_LENGTH := 22.0
const LANE_MIN_LENGTH := 12.0
const JUNCTION_EPS := 0.5       ## two road vertices this close are the same junction


## The whole of VIL-003: ground, through road, common, landmark slot, then
## the form's streets and lanes. Returns a fresh `VillagePlan`; `spec` is not
## modified. An unsupported form returns a plan with the site and nothing
## else, so callers can tell "not mine" from "failed".
static func plan(spec: VillageSpec) -> VillagePlan:
	var out := VillagePlan.new(spec)
	if spec == null or not spec.valid():
		push_error("VillageSitePlanner: invalid spec")
		return out
	if spec.form == &"":
		push_error("VillageSitePlanner: spec.generate() has not been called")
		return out
	out.site = site_rect(spec)
	if not (spec.form in FORMS_SUPPORTED):
		return out

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("site|%d|%s" % [spec.seed, spec.form])

	# 1. the road that goes through, before anything else
	var through: PackedVector2Array = _through_road(out.site, spec, rng)
	out.roads.append(_road(through, &"through", spec.wealth))

	# 2. the common, on it
	if spec.form == &"green":
		_plan_green(out, spec, through)
	else:
		_plan_street(out, spec, through, rng)
	return out


## The ground the village stands on: a square centred on the origin, sized so
## the built area lands in the middle of §9.1's density band. Deterministic,
## and independent of the road -- the road is laid inside it.
static func site_rect(spec: VillageSpec) -> Rect2:
	var built: float = float(spec.households) * HOUSE_FOOTPRINT
	for row in spec.programme:
		if row["kind"] == &"house":
			continue
		built += float(VillageSpec.AREA_PER_KIND.get(row["kind"], 60.0))
	var side: float = clampf(sqrt(built / TARGET_DENSITY), SITE_MIN_SIDE, SITE_MAX_SIDE)
	return Rect2(Vector2(-side * 0.5, -side * 0.5), Vector2(side, side))


## A road dictionary carrying its §5 class properties, so every later reader
## (the builder's ribbons, RoadCheck's width rule, the nav grid's floor) gets
## width and verge from one table.
static func _road(points: PackedVector2Array, cls: StringName, wealth: float) -> Dictionary:
	var row: Dictionary = ROAD_CLASSES[cls]
	var band: int = 0 if wealth < 0.34 else (1 if wealth < 0.67 else 2)
	return {
		"points": points,
		"class": cls,
		"width": float(row["width"]),
		"verge": float(row["verge"]),
		"surface": String(row["surface"][band]),
	}


## The ribbon polygon of a road including its verges -- what nothing may
## stand in (§9.2 "clear").
static func road_ribbon(road: Dictionary, with_verge := false) -> PackedVector2Array:
	var half: float = float(road["width"]) * 0.5
	if with_verge:
		half += float(road["verge"])
	return Poly.ribbon(road["points"], half)


# ------------------------------------------------------------ the through road

## West edge to east edge -- two DIFFERENT sides of the site -- as the sum of
## a half-wave and a full wave, sampled every ~10 m. Both amplitudes are
## drawn from the seed, so the bend is different per village but always
## inside §5's limits.
static func _through_road(site: Rect2, spec: VillageSpec, rng: RandomNumberGenerator) -> PackedVector2Array:
	var length: float = site.size.x
	var a1: float = rng.randf_range(BEND_A1.x, BEND_A1.y) * length * (1.0 if rng.randf() < 0.5 else -1.0)
	var a2: float = rng.randf_range(BEND_A2.x, BEND_A2.y) * length * (1.0 if rng.randf() < 0.5 else -1.0)
	# the green wants the road down one side of it; the street form runs it
	# through the middle with houses on both sides.
	var offset: float = -0.12 * length if spec.form == &"green" else 0.0
	var samples: int = maxi(THROUGH_MIN_SAMPLES, int(ceil(length / THROUGH_SAMPLE_M)))
	var pts := PackedVector2Array()
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var x: float = site.position.x + length * t
		var y: float = offset + a1 * sin(PI * t) + a2 * sin(TAU * t)
		pts.append(Vector2(x, y))
	return pts


## How far the polyline strays from the straight line between its ends. §5's
## "never a straight line the whole width of the site" is this being > 0.
static func bow(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var a: Vector2 = points[0]
	var b: Vector2 = points[points.size() - 1]
	var dir: Vector2 = (b - a).normalized()
	var worst := 0.0
	for i in range(1, points.size() - 1):
		var v: Vector2 = points[i] - a
		worst = maxf(worst, absf(v.cross(dir)))
	return worst


# ------------------------------------------------------- the common and the rest

## `street`: one road, houses on both sides, the common a widening of it, and
## a couple of back lanes for the farms at either end. Below 25 people the
## common shrinks to the well and the village is a hamlet.
static func _plan_street(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		rng: RandomNumberGenerator) -> void:
	var site: Rect2 = out.site
	var hamlet: bool = spec.population < HAMLET_POPULATION
	var target: float = HAMLET_COMMON_AREA if hamlet else _common_area(spec, site)
	var width: float = WELL_PLOT_SIDE if hamlet else clampf(sqrt(target * 1.6), 12.0, site.size.x * 0.35)
	var height: float = WELL_PLOT_SIDE if hamlet else maxf(target / width, 9.0)

	var mid: float = 0.0   # the common sits mid-village
	var rect: Rect2 = _rect_north_of(through, out.roads[0], mid, width, height, COMMON_ROAD_GAP)
	out.commons.append({"poly": Poly.from_rect(rect), "kind": &"common"})

	# the landmark slot, BEFORE any lot: behind the common, fronting it.
	_reserve_landmark(out, spec, rect, site)

	# back lanes: perpendicular off the through road, on the far side from the
	# common, dead-ending at the farms (§5 "may dead-end at a lot").
	for f in [-0.3, 0.3]:
		var idx: int = _vertex_near_x(through, site.position.x + site.size.x * (0.5 + f))
		var lane: PackedVector2Array = _stub(through, idx, -1.0, LANE_LENGTH, site)
		if lane.size() == 2:
			out.roads.append(_road(lane, &"lane", spec.wealth))


## `green`: houses round an open green, the through road across one side of
## it, and a ring of streets round the other three -- which is what puts a
## frontage on every side of the green.
static func _plan_green(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array) -> void:
	var site: Rect2 = out.site
	var target: float = _common_area(spec, site)
	var want_w: float = clampf(sqrt(target * 1.8), GREEN_MIN_W, site.size.x * 0.40)

	# the ring's two junctions on the through road are REAL vertices of it, so
	# the road graph is connected by shared points and not by near-misses.
	var centre_x: float = site.position.x + site.size.x * 0.5
	var ia: int = _vertex_near_x(through, centre_x - want_w * 0.5 - GREEN_SIDE_CLEAR)
	var ib: int = _vertex_near_x(through, centre_x + want_w * 0.5 + GREEN_SIDE_CLEAR)
	if ib - ia < 2:
		ib = mini(through.size() - 1, ia + 2)
	var left: float = through[ia].x + GREEN_SIDE_CLEAR
	var right: float = through[ib].x - GREEN_SIDE_CLEAR
	var green_w: float = maxf(right - left, GREEN_MIN_W)
	right = left + green_w

	var road_top: float = -INF
	for i in range(ia, ib + 1):
		road_top = maxf(road_top, through[i].y)
	var bottom: float = road_top + out.roads[0]["width"] * 0.5 + out.roads[0]["verge"] + COMMON_ROAD_GAP
	var height: float = maxf(target / green_w, GREEN_MIN_H)
	height = minf(height, site.size.y * 0.22)
	height = maxf(height, GREEN_MIN_H)
	var rect := Rect2(Vector2(left, bottom), Vector2(green_w, height))
	out.commons.append({"poly": Poly.from_rect(rect), "kind": &"common"})

	# the ring: west up, north across, east down -- a loop closed by the
	# through road itself, so the graph is one component with no dead end.
	var ring_y: float = rect.end.y + GREEN_SIDE_CLEAR

	# the landmark slot, before any lot, and beyond the ring street so the
	# churchyard is not laid across the road that fronts it.
	_reserve_landmark(out, spec, rect, site, ring_y + ROAD_CLASSES[&"street"]["width"] * 0.5
		+ ROAD_CLASSES[&"street"]["verge"] + LANDMARK_GAP)
	var nw := Vector2(through[ia].x, ring_y)
	var ne := Vector2(through[ib].x, ring_y)
	out.roads.append(_road(PackedVector2Array([through[ia], nw]), &"street", spec.wealth))
	out.roads.append(_road(PackedVector2Array([nw, ne]), &"street", spec.wealth))
	out.roads.append(_road(PackedVector2Array([ne, through[ib]]), &"street", spec.wealth))


## §9.1's common: >= 150 m^2, growing a little with the households that have
## to stand on it, capped so it never eats the site.
static func _common_area(spec: VillageSpec, site: Rect2) -> float:
	var want: float = COMMON_MIN_AREA + float(spec.households) * 6.0
	return clampf(want, COMMON_MIN_AREA, site.size.x * site.size.y * 0.10)


## A rectangle sitting just north of the road, `width` x `height`, centred on
## `at_x`, clear of the carriageway and its verge by `gap`.
static func _rect_north_of(points: PackedVector2Array, road: Dictionary, at_x: float,
		width: float, height: float, gap: float) -> Rect2:
	var left: float = at_x - width * 0.5
	var right: float = at_x + width * 0.5
	var road_top: float = -INF
	for p in points:
		if p.x >= left - 6.0 and p.x <= right + 6.0:
			road_top = maxf(road_top, p.y)
	if road_top == -INF:
		road_top = 0.0
	var bottom: float = road_top + float(road["width"]) * 0.5 + float(road["verge"]) + gap
	return Rect2(Vector2(left, bottom), Vector2(width, height))


## §2.1: the landmark slot is taken before any house lot. It goes behind the
## common, fronting it, so the church looks over the green from every side of
## it. `front` is the edge that faces the common.
static func _reserve_landmark(out: VillagePlan, spec: VillageSpec, common: Rect2, site: Rect2,
		min_bottom := -INF) -> void:
	var kinds: Array = []
	for row in spec.programme:
		kinds.append(row["kind"])
	var kind: StringName = &"shrine"
	var area: float = LANDMARK_AREA_SMALL
	if &"temple" in kinds:
		kind = &"temple"
		area = LANDMARK_AREA
	elif &"church" in kinds:
		kind = &"church"
		area = LANDMARK_AREA
	var bottom: float = maxf(common.end.y + LANDMARK_GAP, min_bottom)
	var avail: float = site.end.y - 4.0 - bottom
	var width: float = clampf(sqrt(area * 1.1), 10.0, common.size.x + 8.0)
	var height: float = clampf(area / width, 8.0, maxf(avail, 8.0))
	if avail < 8.0:
		# no room behind: sit the landmark beside the common instead
		bottom = common.position.y
		var side_x: float = common.position.x - LANDMARK_GAP - width
		out.landmark_site = _landmark_dict(Rect2(Vector2(side_x, bottom), Vector2(width, height)), kind, true)
		return
	out.landmark_site = _landmark_dict(Rect2(Vector2(common.get_center().x - width * 0.5, bottom),
		Vector2(width, height)), kind, false)


static func _landmark_dict(rect: Rect2, kind: StringName, beside: bool) -> Dictionary:
	var front := PackedVector2Array()
	if beside:
		front.append(Vector2(rect.end.x, rect.position.y))
		front.append(rect.end)
	else:
		front.append(rect.position)
		front.append(Vector2(rect.end.x, rect.position.y))
	return {"poly": Poly.from_rect(rect), "kind": kind, "front": front}


## A perpendicular stub off `points[i]`, `sign` < 0 pointing south, clipped to
## the site. Two points, or empty when there is no room for a lane at all.
static func _stub(points: PackedVector2Array, i: int, sign: float, length: float, site: Rect2) -> PackedVector2Array:
	var start: Vector2 = points[i]
	var a: int = maxi(0, i - 1)
	var b: int = mini(points.size() - 1, i + 1)
	var tangent: Vector2 = (points[b] - points[a]).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	if signf(normal.y) != signf(sign):
		normal = -normal
	var room: float = (start.y - (site.position.y + 3.0)) if sign < 0.0 else ((site.end.y - 3.0) - start.y)
	var reach: float = minf(length, room / maxf(absf(normal.y), 0.2))
	if reach < LANE_MIN_LENGTH:
		return PackedVector2Array()
	return PackedVector2Array([start, start + normal * reach])


static func _vertex_near_x(points: PackedVector2Array, x: float) -> int:
	var best: int = 0
	var best_d: float = INF
	for i in range(points.size()):
		var d: float = absf(points[i].x - x)
		if d < best_d:
			best_d = d
			best = i
	return clampi(best, 1, maxi(1, points.size() - 2))


# ------------------------------------------------------------------- junctions

## Every place two roads share a point, with the directions of all the road
## ends meeting there. §5: "junctions are >= 30 deg and >= 8 m apart".
## {"pos": Vector2, "dirs": Array[Vector2], "roads": Array[int]}
static func junctions(plan: VillagePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(plan.roads.size()):
		var pi: PackedVector2Array = plan.roads[i]["points"]
		for vi in range(pi.size()):
			for j in range(i + 1, plan.roads.size()):
				var pj: PackedVector2Array = plan.roads[j]["points"]
				for vj in range(pj.size()):
					if pi[vi].distance_to(pj[vj]) > JUNCTION_EPS:
						continue
					var hit: int = -1
					for k in range(out.size()):
						if (out[k]["pos"] as Vector2).distance_to(pi[vi]) <= JUNCTION_EPS:
							hit = k
							break
					if hit < 0:
						out.append({"pos": pi[vi], "dirs": _dirs_at(pi, vi), "roads": [i]})
						hit = out.size() - 1
					var dirs: Array = out[hit]["dirs"]
					var roads: Array = out[hit]["roads"]
					if not (j in roads):
						roads.append(j)
						for d in _dirs_at(pj, vj):
							dirs.append(d)
					if not (i in roads):
						roads.append(i)
	return out


static func _dirs_at(points: PackedVector2Array, i: int) -> Array:
	var out: Array = []
	if i > 0:
		out.append((points[i - 1] - points[i]).normalized())
	if i < points.size() - 1:
		out.append((points[i + 1] - points[i]).normalized())
	return out


## The number of connected components of the road graph: roads sharing a
## point are in the same component. §9.2's "connected" rule is this == 1.
static func road_components(plan: VillagePlan) -> int:
	var n: int = plan.roads.size()
	if n == 0:
		return 0
	var parent: Array[int] = []
	for i in range(n):
		parent.append(i)
	for i in range(n):
		for j in range(i + 1, n):
			if _roads_touch(plan.roads[i]["points"], plan.roads[j]["points"]):
				var ri: int = _find(parent, i)
				var rj: int = _find(parent, j)
				if ri != rj:
					parent[ri] = rj
	var roots := {}
	for i in range(n):
		roots[_find(parent, i)] = true
	return roots.size()


static func _roads_touch(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for p in a:
		for q in b:
			if p.distance_to(q) <= JUNCTION_EPS:
				return true
	return false


static func _find(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i
