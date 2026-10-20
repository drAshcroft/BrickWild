class_name VillageCrestForm
extends RefCounted
## `crest`: a compact village perched on a hilltop or the head of a spur, a
## ring street laid along a contour just below the summit, the landmark and
## the common on the top, the through road passing at the hill's foot and one
## or two approaches climbing from it to a gate in the ring (VTER-FORM-CREST,
## docs/VILLAGE_TERRAIN.md "The crest form"). Eze, Monteriggioni, Civita di
## Bagnoregio, Beni Isguen.
##
## The ground derives this form at row 3 of the form rule. The layout, in the
## planners' own frame -- the SUMMIT is the origin; the through road runs west
## to east south of it (`VillageSiting` sites the frame so: `frame()`):
##
##   1. the site: a rectangle about the ring, the through road's strip to its
##      south, sized by the ring's radius
##   2. the through road at the hill's foot, routed by grade through a pinned
##      column due south of the summit
##   3. the common: a small disc on the summit
##   4. the RING: a closed street of chords laid on a contour of the ground
##      (one height all round, found at each bearing), its radius set by the
##      households; houses stand on both its sides
##   5. the approach: a street (steps where the ground makes it so) from the
##      through road to the ring's south gate; a path on to the common's well.
##      A larger village has a second approach.
##   6. the landmark's slot on the ring's inner side, where the ground is
##      highest; the lot planner puts the church there (`place_landmark`)
##
## `plan.crest` carries it: {"summit": Vector2 (the plan's origin), "radius":
## the ring's mean radius, "ring_height": its contour height or NAN flat,
## "gate": the south gate, "approaches": int, "church_dir": the bearing the
## church is aimed at}.
##
## Pure: the same seeded stream as the other forms, the spec never written to.

const COMMON_RADIUS := 8.0
## The depth of the inner band, ring street to common: the church's lot, or a
## row of houses backing on the common.
const INNER_BAND := 28.0
const RING_ROAD_HALF := 3.0
const R_MIN := COMMON_RADIUS + INNER_BAND + RING_ROAD_HALF
const HOUSEHOLDS_FREE := 25
const R_PER_HOUSEHOLD := 1.2
## Ground the outer row of lots takes beyond the ring street, and the site's
## margin beyond that.
const OUTER_BAND := 28.0
const SITE_MARGIN := 14.0
## The through road passes this far beyond the outer row's back, and its own
## lots (the tavern, the smithy) have this much ground south of it.
const ROAD_GAP := 12.0
const ROAD_LOTS_M := 45.0
## The road may rise or fall off its pin this much: no nearer the ring.
const ROAD_ROOM_M := 15.0
const CHORD_M := 19.0
const CHORDS_MIN := 8
const CHORDS_MAX := 24
## Chords to an arc (one road).
const ARC_CHORDS := 1
const RING_CLAMP := Vector2(0.6, 1.8)
const SECOND_APPROACH_POP := 100
## The summit search (`frame`).
const SUMMIT_REACH_M := 200.0
const SUMMIT_STEP_M := 15.0
const SUMMIT_PROMINENCE_M := 5.0
const SUMMIT_TIE_M := 0.5
const YAW_STEPS := 24
const W_ROAD_EXTRA := 2.0
const W_APPROACH_OVER := 20.0
const W_APPROACH_MEAN := 4.0
const APPROACH_FREE := 0.12
const HIGH_CLEAR_SLACK := 0.5
const ANGLES_PREFERRED := 60.0       ## the church stands this far round from the gate


# ------------------------------------------------------------------ the plan

static func plan(spec: VillageSpec, _extra_lanes := 0, site_scale := 1.0,
		ground: VillageTerrain = null) -> VillagePlan:
	var out := VillagePlan.new(spec)
	var radius: float = ring_radius(spec, site_scale)
	var road_y: float = radius + RING_ROAD_HALF + OUTER_BAND + ROAD_GAP
	out.site = site_rect(radius)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("site|%d|%s" % [spec.seed, spec.form])
	if ground != null:
		out.ground = ground
		out.site_anchor = ground.site_anchor
		out.site_yaw = ground.site_yaw
	# 2. the through road, at the hill's foot
	var through: PackedVector2Array = VillageSitePlanner._through_road(out.site, spec, rng)
	var current: float = VillageLotPlanner._polyline_y_at_x(through, 0.0)
	through = VillageSitePlanner._shift_points(through, Vector2(0.0, road_y - current))
	if ground != null:
		var half_road: float = float(VillageSitePlanner.ROAD_CLASSES[&"through"]["width"]) * 0.5 \
			+ float(VillageSitePlanner.ROAD_CLASSES[&"through"]["verge"])
		var top: float = road_y - ROAD_ROOM_M - half_road - VillageSitePlanner.SITE_MARGIN_M
		var strip := Rect2(Vector2(out.site.position.x, top), Vector2(out.site.size.x, out.site.end.y - top))
		through = VillageSitePlanner._route_through(through, strip, ground)
	out.roads.append(VillageSitePlanner._road(through, &"through", spec.wealth))
	# 3. the common on the summit
	var summit := Vector2.ZERO
	out.commons.append({"poly": VillageSitePlanner._circle_polygon(summit, COMMON_RADIUS, 16), "kind": &"common"})
	# 4. the ring on a contour
	var ring_h := NAN
	var chords: int = clampi(int(round(TAU * radius / CHORD_M)), CHORDS_MIN, CHORDS_MAX)
	if ground != null:
		ring_h = _ring_height(ground, summit, radius)
		# an elongated contour (a spur) is longer than the circle: more chords
		var rough: PackedVector2Array = ring_points(ground, summit, radius, 24, ring_h)
		var perimeter := 0.0
		for k in range(rough.size()):
			perimeter += rough[k].distance_to(rough[(k + 1) % rough.size()])
		chords = clampi(int(round(perimeter / CHORD_M)), CHORDS_MIN, CHORDS_MAX * 2)
	var ring: PackedVector2Array = ring_points(ground, summit, radius, chords, ring_h)
	# the ring in ARCS of several chords each: a junction every arc, not every
	# chord, so the lot planner's frontage runs the arc's length
	var arcs: int = clampi(int(round(float(chords) / float(ARC_CHORDS))), 1, chords)
	for a in range(arcs):
		var k0: int = a * chords / arcs
		var k1: int = (a + 1) * chords / arcs
		var pts := PackedVector2Array()
		for k in range(k0, k1 + 1):
			pts.append(ring[k % chords])
		out.roads.append(VillageSitePlanner._road(pts, &"street", spec.wealth))
	# 5. the approaches
	var gate: Vector2 = ring[0]
	var join_i: int = VillageSitePlanner._vertex_near_x(through, gate.x)
	out.roads.append(VillageSitePlanner._road(PackedVector2Array([through[join_i], gate]),
		&"street", spec.wealth))
	var approaches := 1
	var walk: Vector2 = (summit - gate).normalized()
	out.roads.append(VillageSitePlanner._road(PackedVector2Array([gate, summit - walk * 1.6]),
		&"path", spec.wealth))
	if spec.population >= SECOND_APPROACH_POP:
		var second := _second_approach(out, spec, through, ring, ground)
		if not second.is_empty():
			out.roads.append(second)
			approaches = 2
	# 6. the landmark's slot, inside the ring where the ground is highest
	var dir: Vector2 = church_direction(ground, summit, radius, ring)
	out.crest = {"summit": summit, "radius": radius, "ring_height": ring_h, "gate": gate,
		"approaches": approaches, "church_dir": dir}
	_reserve_landmark(out, spec, summit + dir * (COMMON_RADIUS + 11.0))
	var ground_shore := false
	if ground != null:
		VillageSitePlanner.grade_roads(out)
		ground_shore = VillageGroundWater.add(out)
	if spec.water != &"none" and not (ground_shore and spec.water in [&"coast", &"lake"]):
		var water_plan: Dictionary = VillageWaterPlan.build(spec, out.site, out.roads, out.commons)
		for water in water_plan["water"]:
			out.water.append(water)
	out.water_crossings = VillageWaterPlan.crossings(out.water, out.roads)
	return out


## The ring street's mean radius: the inner band, the common and the street
## itself, grown by 1.2 m of radius for every household past 25 (and by the
## lot planner's retries when everyone is not housed).
static func ring_radius(spec: VillageSpec, site_scale := 1.0) -> float:
	var r: float = R_MIN + R_PER_HOUSEHOLD * float(maxi(0, spec.households - HOUSEHOLDS_FREE))
	return r * maxf(site_scale, 1.0)


## The ring, the outer row, the through road's strip and the margins.
static func site_rect(radius: float) -> Rect2:
	var half: float = radius + RING_ROAD_HALF + OUTER_BAND + SITE_MARGIN
	var road_y: float = radius + RING_ROAD_HALF + OUTER_BAND + ROAD_GAP
	var bottom: float = road_y + ROAD_LOTS_M
	var side: float = minf(2.0 * half, VillageSitePlanner.SITE_MAX_SIDE)
	return Rect2(Vector2(-side * 0.5, -half), Vector2(side, half + bottom))


# --------------------------------------------------------------- the contour

## The height the ring is laid at: the mean of the ground round the mean
## radius.
static func _ring_height(ground: VillageTerrain, c: Vector2, radius: float) -> float:
	var sum := 0.0
	var n := 24
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		sum += ground.height_at(c + Vector2(cos(a), sin(a)) * radius)
	return sum / float(n)


## The ring's vertices, bearing 90 degrees (due south, +y) first, counter to
## the plan's own handedness after it. On ground each is the point along its
## bearing, within RING_CLAMP of the mean radius, where the ground is at
## `height` (the crossing nearest the mean radius); the radii are then
## smoothed. Flat: a circle.
static func ring_points(ground: VillageTerrain, c: Vector2, radius: float, n: int,
		height: float) -> PackedVector2Array:
	var radii := PackedFloat64Array()
	for k in range(n):
		var a: float = PI * 0.5 + TAU * float(k) / float(n)
		var dir := Vector2(cos(a), sin(a))
		radii.append(radius if ground == null else _contour_radius(ground, c, dir, radius, height))
	if ground != null:
		for _pass in range(2):
			var smooth := PackedFloat64Array()
			for k in range(n):
				smooth.append((radii[(k + n - 1) % n] + 2.0 * radii[k] + radii[(k + 1) % n]) * 0.25)
			radii = smooth
	var pts := PackedVector2Array()
	for k in range(n):
		var a2: float = PI * 0.5 + TAU * float(k) / float(n)
		pts.append(c + Vector2(cos(a2), sin(a2)) * radii[k])
	return pts


static func _contour_radius(ground: VillageTerrain, c: Vector2, dir: Vector2, radius: float,
		height: float) -> float:
	var lo: float = radius * RING_CLAMP.x
	var hi: float = radius * RING_CLAMP.y
	var best: float = radius
	var best_gap := INF
	var prev_r := lo
	var prev_d: float = ground.height_at(c + dir * lo) - height
	var r := lo + 0.5
	while r <= hi + 1e-6:
		var d: float = ground.height_at(c + dir * r) - height
		if (prev_d >= 0.0) != (d >= 0.0):
			var t: float = prev_d / (prev_d - d) if absf(prev_d - d) > 1e-9 else 0.5
			var at: float = prev_r + t * (r - prev_r)
			if absf(at - radius) < best_gap:
				best_gap = absf(at - radius)
				best = at
		prev_r = r
		prev_d = d
		r += 0.5
	if best_gap == INF:
		# the ground never reaches the contour in the clamp: the end nearer it
		var d_lo: float = absf(ground.height_at(c + dir * lo) - height)
		var d_hi: float = absf(ground.height_at(c + dir * hi) - height)
		best = lo if d_lo < d_hi else hi
	return best


# ------------------------------------------------------- approaches and church

## A second climb for a larger village: from the through road to the ring
## vertex about 65 degrees round from the south gate, on whichever side the
## ground there is gentler. {} when there is no room.
static func _second_approach(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		ring: PackedVector2Array, ground: VillageTerrain) -> Dictionary:
	var n: int = ring.size()
	var step: int = maxi(2, int(round(65.0 / (360.0 / float(n)))))
	var best := {}
	var best_g := INF
	for s in [1, -1]:
		var gate: Vector2 = ring[(s * step + n) % n]
		var j: int = VillageSitePlanner._vertex_near_x(through, gate.x)
		var pts := PackedVector2Array([through[j], gate])
		if pts[0].distance_to(pts[1]) < 12.0:
			continue
		var g := 0.0 if ground == null else VillageRoadRouter.grade_of(ground, pts)
		if g < best_g - 1e-9:
			best_g = g
			best = VillageSitePlanner._road(pts, &"street", spec.wealth)
	return best


## The bearing the church is aimed at: the unit vector from the summit. Of
## the bearings 40 degrees or more round from the gate, the one whose ground
## at the church's depth is highest (to a quarter metre), nearest
## ANGLES_PREFERRED round the circle on a tie; flat ground: the preferred one.
static func church_direction(ground: VillageTerrain, c: Vector2, radius: float,
		ring: PackedVector2Array) -> Vector2:
	var best := Vector2.ZERO
	var best_h := -INF
	var best_off := INF
	var depth: float = COMMON_RADIUS + 11.0
	for deg in range(40, 321, 10):
		# measured from the south gate, either way round
		var a: float = PI * 0.5 + deg_to_rad(float(deg))
		var dir := Vector2(cos(a), sin(a))
		var h := 0.0 if ground == null else snappedf(ground.height_at(c + dir * depth), 0.25)
		var off: float = absf(minf(float(deg), 360.0 - float(deg)) - ANGLES_PREFERRED)
		if h > best_h + 1e-9 or (is_equal_approx(h, best_h) and off < best_off - 1e-9):
			best_h = h
			best_off = off
			best = dir
	return best


static func _reserve_landmark(out: VillagePlan, spec: VillageSpec, centre: Vector2) -> void:
	var kind: StringName = &"shrine"
	var area: float = VillageSitePlanner.LANDMARK_AREA_SMALL
	for row in spec.programme:
		if row["kind"] == &"temple":
			kind = &"temple"
			area = VillageSitePlanner.LANDMARK_AREA
			break
		if row["kind"] == &"church":
			kind = &"church"
			area = VillageSitePlanner.LANDMARK_AREA
	var side: float = clampf(sqrt(area * 0.8), 10.0, 14.0)
	var rect := Rect2(centre - Vector2.ONE * side * 0.5, Vector2.ONE * side)
	out.landmark_site = VillageSitePlanner._landmark_dict(rect, kind, false)


## The lot planner's hook (cut_measured): the church on the ring's inner
## frontage in front of the bearing the plan aimed it at, where the ground is
## highest. False when no legal frontage there: the lot planner goes on as it
## would for any form.
static func place_landmark(plan: VillagePlan, job: Dictionary) -> bool:
	if plan.crest.is_empty():
		return false
	var dir: Vector2 = plan.crest["church_dir"]
	var target: Vector2 = Vector2(plan.crest["summit"]) \
		+ dir * (float(plan.crest["radius"]) - RING_ROAD_HALF - 1.0)
	# the church fronts the ring from inside, downhill if it must: its steps are
	# the terrace's (door_ok: the lot planner's front-uphill preference is waived)
	job["door_ok"] = true
	if not VillageLotPlanner._place_landmark_near(plan, job, target):
		return false
	# nothing else stands nearer the top than the church: the landmark is the
	# highest building (to the ground's own fall)
	var at: Vector2 = VillageMeasure.centre(VillageMeasure.footprint_poly(plan.buildings.back()))
	if plan.ground != null:
		plan.crest["high_m"] = plan.ground.height_at(at)
	return true


## Whether `poly` stands on the ground the church keeps for itself: nearer the
## summit than the church is: whose middle stands within HIGH_CLEAR_SLACK of
## the church's own height or above it. Lots other than the
## church's own are refused there (VillageLotPlanner._site_clear).
static func holds_high_ground(plan: VillagePlan, poly: PackedVector2Array) -> bool:
	if plan.ground == null or not plan.crest.has("high_m"):
		return false
	return plan.ground.height_at(VillageMeasure.centre(poly)) > float(plan.crest["high_m"]) - HIGH_CLEAR_SLACK


# ----------------------------------------------------------------- the siting

## The frame for a crest village (VillageSiting.site calls this for the form):
## the anchor IS the summit, and only the yaw is chosen. The summit is the
## highest dry point within SUMMIT_REACH_M of the caller's origin that stands
## SUMMIT_PROMINENCE_M over the 30-150 m ring round it, with the site's
## corners on the grid; ties within SUMMIT_TIE_M go to the nearest the origin.
## The yaw is VillageSiting's own score of the flat plan's road, common and
## lattice, plus how steeply the straight approach climbs from the through
## road to the ring's gate. {} when the ground has no such summit: the
## caller falls back to the generic frame.
static func frame(t: VillageTerrain, flat: VillagePlan, spec: VillageSpec) -> Dictionary:
	var anchor: Vector2 = summit_of(t, flat.site)
	if is_nan(anchor.x):
		return {}
	var samples: Dictionary = VillageSiting._samples(flat)
	var radius: float = ring_radius(spec)
	var road_y: float = radius + RING_ROAD_HALF + OUTER_BAND + ROAD_GAP
	var bounds: Rect2 = t.bounds()
	var best := {}
	var any_cover := false
	for k in range(YAW_STEPS):
		any_cover = any_cover or VillageSiting._covered(bounds, flat.site, anchor, TAU * float(k) / float(YAW_STEPS))
	var dyaw := TAU / float(YAW_STEPS)
	var yaws: Array[float] = []
	for k in range(YAW_STEPS):
		yaws.append(TAU * float(k) / float(YAW_STEPS))
	for _round in range(4):
		for yaw in yaws:
			if any_cover and not VillageSiting._covered(bounds, flat.site, anchor, yaw):
				continue
			var s: Dictionary = VillageSiting._score(t, samples, anchor, yaw, PackedVector2Array())
			# the common sits on the summit whatever the yaw: its own slope term
			# says nothing here; the road across the foot is what the yaw is for
			var extra: float = _approach_term(t, anchor, yaw, radius, road_y) + W_ROAD_EXTRA * float(s["terms"]["road"]) \
				- float(s["terms"]["common"])
			s["terms"]["approach"] = extra
			s["score"] = float(s["score"]) + extra
			if best.is_empty() or float(s["score"]) < float(best["score"]) - 1e-9:
				best = s
		# refine: half steps round the best yaw
		dyaw *= 0.5
		yaws = [float(best["yaw"]) - dyaw, float(best["yaw"]) + dyaw]
	best["fixed_centre"] = false
	best["yaw"] = fposmod(float(best["yaw"]), TAU)
	return best


## How steeply the straight way from the through road (due south of the
## summit, `road_y` out) climbs to the ring's gate, in the caller's ground.
static func _approach_term(t: VillageTerrain, anchor: Vector2, yaw: float, radius: float,
		road_y: float) -> float:
	var a: Vector2 = anchor + Vector2(0.0, road_y).rotated(yaw)
	var b: Vector2 = anchor + Vector2(0.0, radius).rotated(yaw)
	var g: float = absf(t.height_at(a) - t.height_at(b)) / maxf(a.distance_to(b), 1.0)
	return W_APPROACH_OVER * maxf(0.0, g - APPROACH_FREE) + W_APPROACH_MEAN * g


## The summit, a point of the caller's grid, or (NAN, NAN).
static func summit_of(t: VillageTerrain, site: Rect2) -> Vector2:
	var bounds: Rect2 = t.bounds()
	var reach := 0.0
	for p in [site.position, Vector2(site.end.x, site.position.y), site.end, Vector2(site.position.x, site.end.y)]:
		reach = maxf(reach, (p as Vector2).length())
	var free: Rect2 = bounds.grow(-(reach + VillageSiting.CORNER_MARGIN))
	var roomy: bool = free.size.x > 0.0 and free.size.y > 0.0
	var cands: Array[Dictionary] = []
	var wl: float = t.water_level_m
	var n := int(SUMMIT_REACH_M / SUMMIT_STEP_M)
	for j in range(-n, n + 1):
		for i in range(-n, n + 1):
			var p := Vector2(i, j) * SUMMIT_STEP_M
			if p.length() > SUMMIT_REACH_M or not bounds.has_point(p):
				continue
			if roomy and not free.has_point(p):
				continue
			var h: float = t.height_at(p)
			if not is_nan(wl) and h <= wl:
				continue
			cands.append({"p": p, "h": h})
	if cands.is_empty():
		return Vector2(NAN, NAN)
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if absf(float(x["h"]) - float(y["h"])) > 1e-9:
			return float(x["h"]) > float(y["h"])
		return (x["p"] as Vector2).length() < (y["p"] as Vector2).length())
	# the highest points first; the first with the prominence of a summit
	# decides the height, and the nearest the origin within SUMMIT_TIE_M of it
	# is the summit
	var top := NAN
	var pick := Vector2(NAN, NAN)
	var pick_d := INF
	for c in cands:
		if not is_nan(top) and float(c["h"]) < top - SUMMIT_TIE_M:
			break
		if _prominence(t, c["p"]) < SUMMIT_PROMINENCE_M:
			continue
		if is_nan(top):
			top = float(c["h"])
		if (c["p"] as Vector2).length() < pick_d:
			pick_d = (c["p"] as Vector2).length()
			pick = c["p"]
	return pick


## Metres over the mean of the ground 30-150 m round (the analysis' TPI
## annulus, sampled at three radii and twelve bearings).
static func _prominence(t: VillageTerrain, p: Vector2) -> float:
	var sum := 0.0
	var n := 0
	for r in [40.0, 90.0, 140.0]:
		for i in range(12):
			var a: float = TAU * float(i) / 12.0
			sum += t.height_at(p + Vector2(cos(a), sin(a)) * r)
			n += 1
	return t.height_at(p) - sum / float(n)
