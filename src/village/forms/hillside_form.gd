class_name VillageHillsideForm
extends RefCounted
## `hillside`: a terraced village on a slope over a house plot's 17 %
## (VTER-FORM-HILLSIDE, docs/VILLAGE_TERRAIN.md "The hillside form").
##
## The ground derives this form at row 7 of the form rule: median dry slope
## 17 % or more, but not the scattered farming people row 6 sends to its
## hamlets. The real places are Rocamadour, Masouleh and the Amalfi villages:
## ways cut along the contour, one above the other, with houses one or two
## deep on each terrace, and stepped lanes dropping between them.
##
## The layout, in the planners' own frame (the through road west to east,
## which the siting turns onto the contour):
##
##   1. the site: wider along the contour than it is deep, so three terraces
##      and the ground above them fit. The lot planner's retries widen it
##      along the contour only (`site_scale`).
##   2. the through road, routed by grade like every form's, set toward the
##      uphill side of the site to leave the terrace band below it.
##   3. the common and the landmark on the UPHILL side of the road, so the
##      church stands over the village rather than under it.
##   4. TERRACES contour ways below the road, each routed by the same router
##      (`VillageSitePlanner._route_through`): on the 30 % plane they come out
##      within a degree of the contour and stay `street`; on a steeper real
##      hillside `grade_roads` re-classes them as it does every way.
##   5. two END RISERS, straight streets from the through road down to the
##      lowest terrace, each passing through the terrace ends. They lean off
##      the fall line (RISER_LEAN_DEG) so their grade is under a street's
##      30 % -- the road check's junction angle still holds (>= 30 degrees)
##      and `street_contour_share` keeps real, non-contour street length in
##      its denominator, as the survey's hillside villages have.
##   6. stepped CROSS-LANES between each pair of terraces, straight down the
##      fall line: on ground this steep a way between terraces is stairs, not
##      a path (the survey's `steps_ways`).
##   7. a field track off the lowest terrace at either end, out to the site
##      boundary (the way to the fields above, and a farm's own address).
##
## Two to four ways run along the contour (the through road and the three
## terraces), joined by stepped cross-lanes, with the houses one or two deep
## on each terrace -- the arrangement the survey's 33 contour-street and 37
## stair sites ask for.
##
## Pure: every draw comes from the same seeded stream as the other forms, and
## the spec is never written to. Without ground the form is still laid (the
## siting scores the flat plan): the fall line is +Y.

## The site: the flat planner's own square, grown into a band along the
## contour and deep enough for the terraces plus the ground above them.
const WIDTH_X := 1.70
const DEPTH_X := 1.25
const WIDTH_MIN_M := 220.0
const DEPTH_MIN_M := 164.0
## How much ground uphill of the through road the common and its gap and the
## landmark need.
const UPHILL_ROOM_M := 42.0

## Terrace bands below the through road, and the horizontal distance between
## them: at 30 % that is 9 m of height a terrace, 27 m from the top terrace
## to the lowest, inside the survey's steep-site elevation span. The pitch is
## also what a lot on one terrace needs behind it: a house and its back yard
## (and a farm, deeper still) were refused between terraces 20-25 m apart,
## and the cutter then put every house on the through road and the lowest
## terrace, splitting the survey's body.
const TERRACES := 3
const TERRACE_PITCH_M := 30.0
## On gentler ground the pitch grows so a terrace still stands this much
## above the one below it (up to TERRACE_PITCH_MAX_M): the houses of a
## hillside village stand on levels, whatever the slope.
const TERRACE_RISE_M := 6.0
const TERRACE_PITCH_MAX_M := 44.0
## The through road may stray this far either side of its seed line; the
## terraces are offsets of it.
const TERRACE_GAP_M := 20.0
## How hard a level road is held to its seed line (the router's deviation
## weight, scaled): lightly, so it follows the contour.
const LEVEL_HOLD := 0.1

## The street riser at each end of the terrace band leans this far off the
## fall line. A riser of grade g on a slope s runs asin(g / s) off the
## contour, so at 18 degrees off the fall line it is 72 degrees off the
## contour: g = 0.30 * sin(72) = 28.5 %, under a street's 30 % -- and the
## lean costs the terraces less of their length than a steeper one would.
const RISER_LEAN_DEG := 18.0
## A riser is cut to climb no more than this, whatever the ground: on a slope
## steeper than the plane's 30 % it leans further off the fall line (down to
## RISER_LEAN_MAX_DEG) to stay a street, and the pair then lean the SAME way,
## like the ways down a real steep face, so the terraces keep their length.
## Past that it is stairs (`grade_roads` re-classes it), as on a cliff.
const RISER_GRADE := 0.285
## The grade a riser is picked to stay under on the real ground (a street's cap
## less a hair; the plane's own 18 degrees climbs 28.8 %).
const RISER_SEARCH_STEP_M := 10.0
const RISER_MIN_SEP_M := 70.0
const RISER_PICK_GRADE := 0.295
const RISER_LEAN_MAX_DEG := 60.0
## A riser meets a terrace (and the through road) at least this far from its
## line, measured on the line's real tangent: the road check wants 30 degrees
## between any two ways at a junction, and a level line on a real face is not
## parallel to the site's axis. A riser that cannot meet them squarely enough
## is leaned the other way, or not at all.
const JUNCTION_MIN_DEG := 35.0
## How much a riser leaning against the form's chosen hand costs a candidate.
const FLIP_COST_M := 40.0
## The level lines are eased this many times ([1 2 1] on y) before anything is
## joined to them: the router's lattice leaves bends the road check refuses.
const EASE_PASSES := 3
## The road check's bend rule (qa/village_road_check.gd), with a hair to spare.
const BEND_DEG_PER_20M := 24.0
const BEND_RADIUS_M := 12.1
## Where the terrace band's fall is read: the share of the terrace band's
## depth, sampled across the whole width.
const BAND_SAMPLES := 6
const RISER_INSET_M := 8.0
## Clear of the riser at each end before a cross-lane may stand.
const CROSS_CLEAR_M := 14.0
## Where the cross-lanes stand across the terrace band, as a fraction of it.
const CROSS_SPOTS := [0.4, 0.6]
## A cross-lane's shallowest inner tread, as the ground surface lays it, at least
## this (VillageGroundCheck.STAIR_GOING_MIN 0.28 and a little to spare).
const CROSS_GOING_M := 0.30
## Where the field tracks leave the lowest terrace.
const TRACK_SPOTS := [0.18, 0.82]
const UPHILL_TRACK_SPOTS := [0.08, 0.2, 0.8, 0.92]
const TRACK_LEAN_DEG := 15.0
## A track leaves the through road no nearer than the road check's JUNCTION_APART
## to where the common's path joins it: two junctions a metre apart are one
## junction cut badly (Rocamadour: a track 0.6 m from the path, 18 degrees to it).
const TRACK_CLEAR_M := 8.0
## A home's slot stays this far in from its terrace end, clear of the riser.
const SLOT_END_M := 18.0
## The homes each level carries, upper first (normalised; a level has one at least).
const LEVEL_WEIGHTS := [5.0, 1.0, 1.0, 5.0]
## The SHALLOW profile (HILLS-GENERAL): one row of lots less below the lowest
## terrace than the plane keeps (two rows, DEPTH_MIN_M). The lowest terrace then
## has a row of lots to its name where it had two, so it carries two homes fewer
## and the two terraces between carry one more each. The lot planner takes the
## profile where the plane's profile leaves VillageQA a fault and the shallow one
## leaves fewer (`VillageLotPlanner._hill_variant`), not by a slope: Manarola
## (band slope 0.319) wants the plane's, Masouleh (0.330) the shallow one.
const LEVEL_WEIGHTS_SHALLOW := [5.0, 2.0, 2.0, 3.0]
## One row of lots below a terrace: a lot 14 m deep and the site's margin.
const LOT_ROW_M := 16.0
## The tavern stands by a gate (VILLAGES 6: within the place check's 60 m). The
## through road must reach the site's edge at both ends, so where the lot checks
## can only stand the tavern mid-village (Manarola) the lot planner plans again
## with the site cut to a gate distance from it at the near end (`site_crop`):
## from TAVERN_NEAR_M less a step down to GATE_MIN_M, the first whose plan
## VillageQA finds fewer faults in (a gate closer than a lot and its yard is no
## gate by the tavern at all).
const TAVERN_NEAR_M := 56.0
const GATE_STEP_M := 4.0
const GATE_MIN_M := 28.0
const CROP_MIN_W_M := 140.0
## The real steep sites' p10-p90 bands (world_settlements.json, the 46 sites with
## a median slope of 8 % or more; docs/SETTLEMENT_TESTSET.md), measured with
## VillageShape. The form is held to them by `vhillside`, and the lot planner
## counts a miss as a fault when it compares its profiles and gate cuts.
const BAND_ELONGATION := Vector2(1.32, 4.88)
const BAND_CONTOUR := Vector2(0.389, 0.798)
const BAND_SPAN_M := Vector2(14.4, 73.0)
const BAND_STEPS := Vector2(0.0, 46.5)
## Homes beside the common at most (a fourth adds no frontage), and how far
## beyond its short edges the first stands: half its width and one lot's front.
const AROUND_MAX := 3
const AROUND_LOT_FRONT_M := 12.0
const EDGE_INSET_M := 4.0
const SITE_MARGIN_M := 2.0


## The whole site plan of a hillside village. `extra_lanes` is ignored: the
## lot planner's retries buy ground along the contour (`site_scale`), and a
## lane off the through road would be one more way across the terraces. `hill`
## is the lot planner's re-plan: {"crop": Vector2 (x_lo, x_hi), "shallow": bool}.
static func plan(spec: VillageSpec, _extra_lanes := 0, site_scale := 1.0,
		ground: VillageTerrain = null, minimum_depth := 0.0, hill := {}) -> VillagePlan:
	var out := VillagePlan.new(spec)
	out.site = site_rect(spec, site_scale, minimum_depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("site|%d|%s" % [spec.seed, spec.form])
	if ground != null:
		out.ground = ground
		out.site_anchor = ground.site_anchor
		out.site_yaw = ground.site_yaw
	var down: float = _downhill(out.site, ground)
	# how far off the fall line a riser must lean to stay a street here
	var slope: float = band_slope(out.site, ground, down)
	var pitch: float = terrace_pitch(slope)
	if pitch > TERRACE_PITCH_M:
		var deeper: float = out.site.size.y + float(TERRACES) * (pitch - TERRACE_PITCH_M)
		deeper = minf(deeper, VillageSitePlanner.SITE_MAX_SIDE)
		out.site = Rect2(Vector2(out.site.position.x, -deeper * 0.5), Vector2(out.site.size.x, deeper))
	var shallow: bool = bool(hill.get("shallow", false))
	if shallow:
		var less: float = minf(out.site.size.y, DEPTH_MIN_M) - LOT_ROW_M
		out.site = Rect2(Vector2(out.site.position.x, -less * 0.5), Vector2(out.site.size.x, less))
	var lean_deg: float = riser_lean_deg(slope)
	var parallel: bool = lean_deg > RISER_LEAN_DEG + 4.0
	var drift: float = 0.0
	if parallel:
		# the ways lean the same way: the band needs room for the lean
		drift = tan(deg_to_rad(lean_deg)) * pitch * float(TERRACES) * 1.1
		var wider: float = minf(out.site.size.x + drift, VillageSitePlanner.SITE_MAX_SIDE)
		out.site = Rect2(Vector2(-wider * 0.5, out.site.position.y), Vector2(wider, out.site.size.y))
		drift = minf(drift, wider * 0.45)
	var site_crop: Vector2 = hill.get("crop", Vector2.ZERO)
	if site_crop != Vector2.ZERO:
		var x_lo: float = maxf(out.site.position.x, site_crop.x)
		var x_hi: float = minf(out.site.end.x, site_crop.y)
		if x_hi - x_lo >= CROP_MIN_W_M:
			out.site = Rect2(Vector2(x_lo, out.site.position.y), Vector2(x_hi - x_lo, out.site.size.y))
	var through: PackedVector2Array = VillageSitePlanner._through_road(out.site, spec, rng)
	# set the road toward the uphill side, leaving the terrace band below it
	var shift: float = -down * maxf(0.0, out.site.size.y * 0.5 - UPHILL_ROOM_M)
	for i in range(through.size()):
		through[i] = Vector2(through[i].x, through[i].y + shift)
	if ground != null:
		# A level road: the contour through the seed's point. The terraces are
		# contours too, so the five lines run parallel; a road routed at the
		# cart's 12 % would cross the terraces below it on a real hillside.
		through = _level(ground, out.site, through, through[VillageSitePlanner._vertex_near_x(
			through, 0.0)].y, float(VillageSitePlanner.ROAD_CLASSES[&"through"]["grade_max"]))
	var through_road: Dictionary = VillageSitePlanner._road(through, &"through", spec.wealth)
	through_road["band_slope"] = slope     # a planning key, like `terrace`
	through_road["shallow"] = shallow
	if ground != null and VillageRoadRouter.grade_of(ground, through) > float(
			VillageSitePlanner.ROAD_CLASSES[&"through"]["grade_max"]) + 1e-6:
		# a level line that still climbs past a cart's 12 % (the face is too steep
		# for any cart road): the village's main street is a stair street, as on
		# the real Manarola; the road check holds a cart road to its cap
		through_road["stepped"] = true
	out.roads.append(through_road)

	# the common and the landmark stand uphill of the road
	var common := _common(out, spec, through, -down, ground)
	out.commons.append({"poly": Poly.from_rect(common), "kind": &"common"})
	var join: Vector2 = through[VillageSitePlanner._vertex_near_x(through, common.get_center().x)]
	var walk: Vector2 = (common.get_center() - join).normalized()
	out.roads.append(VillageSitePlanner._road(
		PackedVector2Array([join, common.get_center() - walk * 1.9]), &"path", spec.wealth))
	_reserve_landmark(out, spec, common, -down)

	# The terraces: contours too, one pitch down the fall line from the road's
	# middle (the router let three seeds run together onto one least-grade line
	# on a curved hill), each kept a lane's width clear of the one above it.
	var terraces: Array[PackedVector2Array] = []
	var mid_i: int = VillageSitePlanner._vertex_near_x(through, 0.0)
	for k in range(1, TERRACES + 1):
		var seed_y: float = through[mid_i].y + down * pitch * float(k)
		var line: PackedVector2Array
		if ground != null:
			line = _level(ground, out.site, through, seed_y,
				float(VillageSitePlanner.ROAD_CLASSES[&"street"]["grade_max"]))
		else:
			line = PackedVector2Array()
			for p in through:
				line.append(Vector2(p.x, p.y + down * pitch * float(k)))
		# never closer than TERRACE_GAP_M to the line above, nor outside the site
		var above: PackedVector2Array = through if k == 1 else terraces[k - 2]
		for i in range(line.size()):
			var floor_y: float = above[i].y + down * TERRACE_GAP_M
			var y: float = line[i].y
			y = maxf(y, floor_y) if down > 0.0 else minf(y, floor_y)
			line[i] = Vector2(line[i].x, clampf(y, out.site.position.y + SITE_MARGIN_M + 3.0,
				out.site.end.y - SITE_MARGIN_M - 3.0))
		terraces.append(_ease(line, mid_i))
	# The risers own the two ends. A terrace runs from where its end's riser
	# stands at its height, so trim it there and keep every road's index. Each
	# riser leans only as far as ITS ground asks (the least that keeps it a
	# street), so a steep end does not cost a gentle one its length.
	var x_top_w: float = out.site.position.x + RISER_INSET_M
	var x_top_e: float = out.site.end.x - RISER_INSET_M - drift
	# converging risers lean inward (west +, east -); parallel ones both east
	var dir_w: float = 1.0
	var dir_e: float = 1.0 if parallel else -1.0
	var pair: Array = pick_pair(ground, out.site, through, terraces, dir_w, dir_e, lean_deg,
		absf(terraces[terraces.size() - 1][terraces[terraces.size() - 1].size() / 2].y - through[through.size() / 2].y))
	x_top_w = pair[0]
	x_top_e = pair[2]
	var lean_w: float = pair[1]
	var lean_e: float = pair[3]
	dir_w = pair[4]
	dir_e = pair[5]
	var tan_w: float = tan(deg_to_rad(lean_w))
	var tan_e: float = tan(deg_to_rad(lean_e))
	var top_w: Vector2 = through[VillageSitePlanner._vertex_near_x(through, x_top_w)]
	var top_e: Vector2 = through[VillageSitePlanner._vertex_near_x(through, x_top_e)]
	var terrace_roads: Array[int] = []
	for k in range(terraces.size()):
		var x0: float = _riser_x(terraces[k], top_w, dir_w, tan_w)
		var x1: float = _riser_x(terraces[k], top_e, dir_e, tan_e)
		if is_nan(x0):
			x0 = terraces[k][0].x
		if is_nan(x1):
			x1 = terraces[k][terraces[k].size() - 1].x
		terraces[k] = _trim_x(terraces[k], x0, x1)
		terrace_roads.append(-1)
		if terraces[k].size() >= 2:
			terrace_roads[k] = out.roads.size()
			var road: Dictionary = VillageSitePlanner._road(terraces[k], &"street", spec.wealth)
			# the lot planner's own hook strings the households along these
			road["terrace"] = k
			out.roads.append(road)
	# the two end risers, through every terrace end on their way
	_riser(out, through, terraces, 0.0, x_top_w, dir_w, tan_w)
	_riser(out, through, terraces, 1.0, x_top_e, dir_e, tan_e)
	for k in range(terraces.size()):
		if terrace_roads[k] >= 0:
			out.roads[terrace_roads[k]]["points"] = terraces[k]

	# Stepped cross-lanes between the terraces, down the fall line. The same x
	# for every gap: a cross-lane and the one below it meet the terrace they
	# share at ONE junction, not two a metre or two apart.
	var cross_lo: float = -INF
	var cross_hi: float = INF
	for t in terraces:
		cross_lo = maxf(cross_lo, t[0].x + CROSS_CLEAR_M)
		cross_hi = minf(cross_hi, t[t.size() - 1].x - CROSS_CLEAR_M)
	# On given ground a lane too steep for a stair (HILLS-STAIRS) leans off the
	# fall line to a column of the terrace below where it is not; the next gap's
	# lane starts where this one ends (one junction), leaning back the other way:
	# the switchback in small.
	var foot_x: Array[float] = []
	var hands: Array[float] = []
	for f in CROSS_SPOTS:
		# on one of the terraces' own vertices, so no short segment is made
		foot_x.append(_column_near(through, lerpf(cross_lo, cross_hi, float(f))))
		hands.append(-1.0 if float(f) < 0.5 else 1.0)   # outward first
	for k in range(terraces.size() - 1):
		for fi in range(CROSS_SPOTS.size()):
			var upper: PackedVector2Array = terraces[k]
			var lower: PackedVector2Array = terraces[k + 1]
			var x: float = foot_x[fi]
			var a: Vector2 = Vector2(x, VillageLotPlanner._polyline_y_at_x(upper, x))
			var xb: float = x
			if ground != null:
				xb = _cross_foot(ground, through, upper, lower, a, cross_lo, cross_hi, hands[fi])
			var b: Vector2 = Vector2(xb, VillageLotPlanner._polyline_y_at_x(lower, xb))
			if a.distance_to(b) < 4.0:
				continue
			if xb != x:
				hands[fi] = signf(x - xb)   # the next one leans back
			terraces[k] = _insert_at_x(terraces[k], x)
			terraces[k + 1] = _insert_at_x(terraces[k + 1], xb)
			out.roads[terrace_roads[k]]["points"] = terraces[k]
			out.roads[terrace_roads[k + 1]]["points"] = terraces[k + 1]
			out.roads.append(VillageSitePlanner._road(PackedVector2Array([a, b]), &"steps", spec.wealth))
			foot_x[fi] = xb

	for k in range(terraces.size()):
		if terrace_roads[k] >= 0:
			terraces[k] = _repair_bends(out, terrace_roads[k], terraces[k])
			out.roads[terrace_roads[k]]["points"] = terraces[k]

	# way out to the fields above: tracks off the lowest terrace
	_field_tracks(out, terraces[terraces.size() - 1], down, ground)
	if ground != null:
		# and the way up to the fields above the village, off the through road
		# clear of the common: on ground this steep, the only streets that climb
		_field_tracks(out, through, -down, ground, UPHILL_TRACK_SPOTS, [join])
	var ground_shore := false
	if ground != null:
		VillageSitePlanner.grade_roads(out)
		ground_shore = VillageGroundWater.add(out)
	if spec.water != &"none" and not (ground_shore and spec.water in [&"coast", &"lake"]) \
			and not (ground_shore and spec.water in [&"river", &"stream"] and VillageGroundWater.has_river(out)):
		var water_plan: Dictionary = VillageWaterPlan.build(spec, out.site, out.roads, out.commons)
		for water in water_plan["water"]:
			out.water.append(water)
	out.water_crossings = VillageWaterPlan.crossings(out.water, out.roads)
	return out


## The site: the flat planner's square grown along the contour, deep enough
## for the terrace band and the ground above it.
static func site_rect(spec: VillageSpec, site_scale := 1.0, minimum_depth := 0.0) -> Rect2:
	var base: float = VillageSitePlanner.site_rect(spec).size.x
	var depth: float = clampf(maxf(base * DEPTH_X, minimum_depth), DEPTH_MIN_M,
		VillageSitePlanner.SITE_MAX_SIDE)
	var width: float = clampf(base * WIDTH_X, WIDTH_MIN_M, VillageSitePlanner.SITE_MAX_SIDE)
	if spec.requested_site_m > 0.0:
		width = minf(width, spec.requested_site_m)
	width = minf(width * maxf(site_scale, 1.0), VillageSitePlanner.SITE_MAX_SIDE)
	if spec.requested_site_m > 0.0:
		width = minf(width, spec.requested_site_m)
	return Rect2(Vector2(-width * 0.5, -depth * 0.5), Vector2(width, depth))


## The level line through (`along[mid]`, `y_seed`) on `ground`, one vertex per
## column of `along` (the flat road's own): the router's least-grade path over
## the ground's height measured from the seed's, so it follows the contour
## wherever one runs inside the site (the same DP, the same heading and turn
## limits, as every road) and ramps the least where it does not. The seed's
## column is pinned: a terrace stands exactly its pitch below the road there.
static func _level(ground: VillageTerrain, site: Rect2, along: PackedVector2Array,
		y_seed: float, cap: float) -> PackedVector2Array:
	var n: int = along.size()
	var i0: int = VillageSitePlanner._vertex_near_x(along, 0.0)
	var target: float = ground.height_at(Vector2(along[i0].x, y_seed))
	var lo: float = site.position.y + SITE_MARGIN_M + 3.0
	var hi: float = site.end.y - SITE_MARGIN_M - 3.0
	# the pinned offset must be a lattice offset
	lo = y_seed - VillageRoadRouter.OFFSET_STEP_M * floor((y_seed - lo) / VillageRoadRouter.OFFSET_STEP_M)
	var xs := PackedFloat64Array()
	var seed := PackedFloat64Array()
	for p in along:
		xs.append(p.x)
		seed.append(y_seed)
	var h := func(a: float, c: float) -> float: return ground.height_at(Vector2(a, c)) - target
	var routed := VillageRoadRouter.route_across(h, xs, seed, lo, hi, cap, ground.water_level_m,
		i0, y_seed, LEVEL_HOLD)
	var out := PackedVector2Array()
	for i in range(n):
		out.append(Vector2(xs[i], routed[i]))
	out[i0] = Vector2(xs[i0], y_seed)
	return out


## The least lean (degrees off the fall line) from `base_deg` up to the maximum
## at which a riser from `x_top` on the through road, through each terrace's
## height, climbs no more than `cap` on `ground` AND meets the through road and
## every terrace at JUNCTION_MIN_DEG or more. Returns (lean, grade); the grade
## is INF where no lean does.
static func pick_lean(ground: VillageTerrain, through: PackedVector2Array,
		terraces: Array[PackedVector2Array], x_top: float, dir: float, base_deg: float,
		cap := RISER_PICK_GRADE) -> Vector2:
	if ground == null:
		return Vector2(base_deg, 0.0)
	var top: Vector2 = through[VillageSitePlanner._vertex_near_x(through, x_top)]
	var lean: float = base_deg
	while lean <= RISER_LEAN_MAX_DEG + 1e-6:
		var pts := PackedVector2Array([top])
		var t: float = tan(deg_to_rad(lean))
		var lines: Array[PackedVector2Array] = [through]
		for line in terraces:
			var x: float = _riser_x(line, top, dir, t)
			if is_nan(x):
				pts.clear()
				break
			pts.append(Vector2(x, VillageLotPlanner._polyline_y_at_x(line, x)))
			lines.append(line)
		if pts.size() >= 2 and _squarely(pts, lines):
			var g: float = VillageRoadRouter.grade_of(ground, pts)
			if g <= cap:
				return Vector2(lean, g)
		lean += 3.0
	return Vector2(RISER_LEAN_MAX_DEG, INF)


## True when the riser `pts` (the through road's point, then one on each
## terrace) crosses each of `lines` (the same order) at JUNCTION_MIN_DEG or more
## to that line's tangent there.
static func _squarely(pts: PackedVector2Array, lines: Array[PackedVector2Array]) -> bool:
	for i in range(pts.size()):
		var seg: Vector2 = (pts[i + 1] - pts[i]) if i + 1 < pts.size() else (pts[i] - pts[i - 1])
		var line: PackedVector2Array = lines[i]
		var x: float = pts[i].x
		var tangent := Vector2(12.0, VillageLotPlanner._polyline_y_at_x(line, x + 6.0)
			- VillageLotPlanner._polyline_y_at_x(line, x - 6.0))
		var ang: float = rad_to_deg(absf(seg.angle_to(tangent)))
		ang = minf(ang, 180.0 - ang)
		if ang < JUNCTION_MIN_DEG:
			return false
		if i > 0 and i + 1 < pts.size():
			var seg2: Vector2 = pts[i] - pts[i - 1]
			var ang2: float = rad_to_deg(absf(seg2.angle_to(tangent)))
			ang2 = minf(ang2, 180.0 - ang2)
			if ang2 < JUNCTION_MIN_DEG:
				return false
	return true


## Where a riser from `top` (leaning `dir` * atan(`tan_lean`) off the fall line)
## meets `line`: the x where the riser's x equals the line's own y-offset from
## the top, solved from the line's actual height there (not its nominal pitch),
## so the terrace ends exactly on the riser it is trimmed to.
static func _riser_x(line: PackedVector2Array, top: Vector2, dir: float, tan_lean: float) -> float:
	# f(x) = dir * (x - top.x) - tan * |y(x) - top.y| is negative at the top and
	# climbs as the riser leans away: the first x where it reaches zero is the
	# meeting. (A fixed-point iteration does not converge where the terrace
	# itself runs steeply across the riser's line, and then the terrace ends
	# off the riser it is trimmed to.) NAN where the line never meets it.
	var x_lo: float = line[0].x
	var x_hi: float = line[line.size() - 1].x
	var prev_x: float = top.x
	var prev_f: float = -tan_lean * absf(VillageLotPlanner._polyline_y_at_x(line, top.x) - top.y)
	if prev_f >= 0.0:
		return top.x
	var step := 1.0
	var x: float = top.x
	while true:
		x += dir * step
		if x < x_lo - 1e-6 or x > x_hi + 1e-6:
			return NAN
		var f: float = dir * (x - top.x) - tan_lean * absf(VillageLotPlanner._polyline_y_at_x(line, x) - top.y)
		if f >= 0.0:
			var t: float = -prev_f / (f - prev_f)
			return lerpf(prev_x, x, t)
		prev_x = x
		prev_f = f
	return NAN


## Where the two risers stand: any pair of tops along the road (a face is
## steeper in some places than others, and a riser that cannot be a street
## takes every terrace with it, since a street must end on a street) with each
## riser a street, the terraces between them at least RISER_MIN_SEP_M long at
## the top and at the lowest level, and the widest such pair preferred (less a
## little for lean). Each riser may lean either way (the form's hand is
## preferred): a level line on a real face runs diagonally across the site, and
## a riser square to it leans with it. With no such pair of STREETS the risers
## are stairs (the real hillsides', Manarola's and Masouleh's): the pair that
## meets every line squarely and leans least. Returns
## [x_w, lean_w, x_e, lean_e, dir_w, dir_e]; with no ground, or no pair that
## works, the site's two ends, as before.
static func pick_pair(ground: VillageTerrain, site: Rect2, through: PackedVector2Array,
		terraces: Array[PackedVector2Array], dir_w: float, dir_e: float, base_deg: float,
		drop_y: float) -> Array:
	var x_w0: float = site.position.x + RISER_INSET_M
	var x_e0: float = site.end.x - RISER_INSET_M
	if dir_e > 0.0:
		x_e0 -= tan(deg_to_rad(base_deg)) * drop_y * 1.1
	var fallback: Array = [x_w0, base_deg, x_e0, base_deg, dir_w, dir_e]
	if ground == null:
		return fallback
	var xs := PackedFloat64Array()
	var x: float = x_w0
	while x <= site.end.x - RISER_INSET_M + 1e-6:
		xs.append(x)
		x += RISER_SEARCH_STEP_M
	if xs[xs.size() - 1] < site.end.x - RISER_INSET_M - 1e-6:
		xs.append(site.end.x - RISER_INSET_M)
	for cap in [RISER_PICK_GRADE, INF]:
		var west: Array[Vector3] = []   # (x, lean, dir)
		var east: Array[Vector3] = []
		for xv in xs:
			for d in [dir_w, -dir_w]:
				var rw: Vector2 = pick_lean(ground, through, terraces, xv, d, base_deg, cap)
				if rw.y < INF:
					west.append(Vector3(xv, rw.x, d))
			for d in [dir_e, -dir_e]:
				var re: Vector2 = pick_lean(ground, through, terraces, xv, d, base_deg, cap)
				if re.y < INF:
					east.append(Vector3(xv, re.x, d))
		var best: Array = []
		var best_score := -INF
		var edge_hi: float = site.end.x - EDGE_INSET_M
		var edge_lo: float = site.position.x + EDGE_INSET_M
		for w in west:
			var bot_w: float = clampf(w.x + w.z * tan(deg_to_rad(w.y)) * drop_y, edge_lo, edge_hi)
			for e in east:
				var bot_e: float = clampf(e.x + e.z * tan(deg_to_rad(e.y)) * drop_y, edge_lo, edge_hi)
				var sep: float = minf(e.x - w.x, bot_e - bot_w)
				if sep < RISER_MIN_SEP_M:
					continue
				var score: float = sep - 0.3 * (w.y + e.y)
				if w.z != dir_w:
					score -= FLIP_COST_M
				if e.z != dir_e:
					score -= FLIP_COST_M
				if score > best_score + 1e-9:
					best_score = score
					best = [w.x, w.y, e.x, e.y, w.z, e.z]
		if not best.is_empty():
			return best
	return fallback


## Where along the road a riser stands: the candidate top x in [x_a, x_b] whose
## riser climbs least steeply with the least lean (a face is steeper in some
## places than others, and a riser that cannot be a street takes the terraces
## with it). Returns (x_top, lean_deg).
static func pick_riser(ground: VillageTerrain, through: PackedVector2Array,
		terraces: Array[PackedVector2Array], x_a: float, x_b: float, dir: float,
		base_deg: float) -> Vector2:
	# x_a is the outer candidate (the site edge side), x_b the inner
	if ground == null:
		return Vector2(x_a, base_deg)
	var best := Vector2(x_a, RISER_LEAN_MAX_DEG)
	var best_key := INF
	var steps: int = int(ceil(absf(x_b - x_a) / RISER_SEARCH_STEP_M))
	for si in range(steps + 1):
		var x: float = x_a + (x_b - x_a) * float(si) / float(maxi(steps, 1))
		var r: Vector2 = pick_lean(ground, through, terraces, x, dir, base_deg)
		# a riser that stays a street beats one that does not; then the least lean
		var key: float = r.x + 0.05 * absf(x - x_a) 			+ (1000.0 + r.y * 1000.0 if r.y > RISER_PICK_GRADE else 0.0)
		if key < best_key - 1e-9:
			best_key = key
			best = Vector2(x, r.x)
	return best


## The median ground slope over the terrace band: what the risers must climb.
static func band_slope(site: Rect2, ground: VillageTerrain, down: float) -> float:
	if ground == null:
		return 0.30
	var slopes := PackedFloat64Array()
	var depth: float = TERRACE_PITCH_M * float(TERRACES)
	var y0: float = site.get_center().y - down * (site.size.y * 0.5 - UPHILL_ROOM_M)
	for j in range(BAND_SAMPLES):
		for i in range(BAND_SAMPLES):
			var p := Vector2(
				site.position.x + site.size.x * (float(i) + 0.5) / float(BAND_SAMPLES),
				y0 + down * depth * float(j) / float(BAND_SAMPLES - 1))
			slopes.append(ground.slope_at(p))
	slopes.sort()
	return slopes[slopes.size() / 2]


## The pitch between terraces on a slope `s`: TERRACE_PITCH_M, or more where
## the ground is gentle enough that it would not stand TERRACE_RISE_M apart.
static func terrace_pitch(s: float) -> float:
	if s <= 1e-6:
		return TERRACE_PITCH_MAX_M
	return clampf(TERRACE_RISE_M / s, TERRACE_PITCH_M, TERRACE_PITCH_MAX_M)


## How far a riser leans off the fall line (degrees) on a slope `s`: the
## plane's fixed RISER_LEAN_DEG, or more where the slope is steeper than a
## street can climb straight down it. A riser of grade g on a slope s runs
## asin(g / s) off the contour, so it leans 90 - asin(g / s) off the fall line.
static func riser_lean_deg(s: float) -> float:
	if s <= RISER_GRADE:
		return RISER_LEAN_DEG
	var lean: float = 90.0 - rad_to_deg(asin(clampf(RISER_GRADE / s, 0.0, 1.0)))
	if lean < RISER_LEAN_DEG + 4.0:
		return RISER_LEAN_DEG
	return clampf(lean, RISER_LEAN_DEG, RISER_LEAN_MAX_DEG)


## Which way the ground falls across the frame: +1 when +Y is downhill. On
## flat ground the form's own convention is +1 (the fall line is +Y).
static func _downhill(site: Rect2, ground: VillageTerrain) -> float:
	if ground == null:
		return 1.0
	var c := site.get_center()
	var h_plus: float = ground.height_at(c + Vector2(0.0, 10.0))
	var h_minus: float = ground.height_at(c - Vector2(0.0, 10.0))
	return 1.0 if h_plus <= h_minus else -1.0


## A rectangle just off the road on `side` (+1 north, -1 south), `width` x
## `height`, centred on the road's vertex nearest the site's middle.
static func _common(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		side: float, ground: VillageTerrain = null) -> Rect2:
	var site: Rect2 = out.site
	var small: bool = spec.population < VillageSitePlanner.HAMLET_POPULATION
	var target: float = VillageSitePlanner.HAMLET_COMMON_AREA if small \
		else VillageSitePlanner._common_area(spec, site)
	var width: float = VillageSitePlanner.WELL_PLOT_SIDE if small \
		else clampf(sqrt(target * 1.6), 12.0, site.size.x * 0.35)
	var height: float = VillageSitePlanner.WELL_PLOT_SIDE if small else maxf(target / width, 9.0)
	var mid: float = through[VillageSitePlanner._vertex_near_x(through, site.get_center().x)].x
	if ground != null:
		# on a real hill, the flattest ground along the road's middle half: the
		# place check wants the common no steeper than the village's median lot
		var best: float = INF
		var best_mid: float = mid
		var step: float = 8.0
		var reach: float = site.size.x * 0.4
		var k: float = -reach
		while k <= reach + 0.01:
			var cand: Rect2 = _common_at(out, through, side, site.get_center().x + k, width, height)
			var fall: float = float(ground.under(Poly.from_rect(cand))["slope_mean"]) + 0.00008 * absf(k)
			if fall < best - 1e-9:
				best = fall
				best_mid = site.get_center().x + k
			k += step
		mid = through[VillageSitePlanner._vertex_near_x(through, best_mid)].x
	return _common_at(out, through, side, mid, width, height)


## The common's rectangle just off the road on `side`, centred on `mid`.
static func _common_at(out: VillagePlan, through: PackedVector2Array, side: float,
		mid: float, width: float, height: float) -> Rect2:
	var site: Rect2 = out.site
	var left: float = mid - width * 0.5
	var right: float = mid + width * 0.5
	var road_edge: float = -INF if side > 0.0 else INF
	for p in through:
		if p.x >= left - 6.0 and p.x <= right + 6.0:
			road_edge = maxf(road_edge, p.y) if side > 0.0 else minf(road_edge, p.y)
	for edge_x in [left, right]:
		var y: float = VillageLotPlanner._polyline_y_at_x(through, edge_x)
		road_edge = maxf(road_edge, y) if side > 0.0 else minf(road_edge, y)
	if road_edge == -INF or road_edge == INF:
		road_edge = 0.0
	var half: float = float(VillageSitePlanner.ROAD_CLASSES[&"through"]["width"]) * 0.5 \
		+ float(VillageSitePlanner.ROAD_CLASSES[&"through"]["verge"])
	var bottom: float = road_edge + side * (half + VillageSitePlanner.COMMON_ROAD_GAP)
	var top: float = bottom + side * height
	var y0: float = minf(bottom, top)
	y0 = clampf(y0, site.position.y + SITE_MARGIN_M,
		site.end.y - SITE_MARGIN_M - height)
	return Rect2(Vector2(left, y0), Vector2(width, height))


## The landmark slot beyond the common on `side`, before any house lot.
static func _reserve_landmark(out: VillagePlan, spec: VillageSpec, common: Rect2,
		side: float) -> void:
	var kinds: Array = []
	for row in spec.programme:
		kinds.append(row["kind"])
	var kind: StringName = &"shrine"
	var area: float = VillageSitePlanner.LANDMARK_AREA_SMALL
	if &"temple" in kinds:
		kind = &"temple"
		area = VillageSitePlanner.LANDMARK_AREA
	elif &"church" in kinds:
		kind = &"church"
		area = VillageSitePlanner.LANDMARK_AREA
	var width: float = clampf(sqrt(area * 1.1), 10.0, common.size.x + 8.0)
	var height: float = clampf(area / width, 8.0, maxf(common.size.y + 4.0, 8.0))
	var edge: float = common.end.y if side > 0.0 else common.position.y
	var bottom: float = edge + side * VillageSitePlanner.LANDMARK_GAP
	var y0: float = minf(bottom, bottom + side * height)
	var front := PackedVector2Array()
	if side > 0.0:
		front.append(Vector2(common.get_center().x - width * 0.5, y0))
		front.append(Vector2(common.get_center().x + width * 0.5, y0))
	else:
		front.append(Vector2(common.get_center().x - width * 0.5, y0 + height))
		front.append(Vector2(common.get_center().x + width * 0.5, y0 + height))
	out.landmark_site = {"poly": Poly.from_rect(Rect2(
		Vector2(common.get_center().x - width * 0.5, y0), Vector2(width, height))),
		"kind": kind, "front": front}


## A street from the through road down to the lowest terrace, through every
## terrace end, leaning inward by `lean` per metre of fall so its grade stays
## under a street's cap. `end` 0 is the west end, 1 the east.
static func _riser(out: VillagePlan, through: PackedVector2Array,
		terraces: Array[PackedVector2Array], end: float, x_top: float, inward: float,
		lean: float) -> void:   # `lean` is the tangent of the lean angle
	if terraces.is_empty() or terraces[terraces.size() - 1].size() < 2:
		return
	var idx: int = VillageSitePlanner._vertex_near_x(through, x_top)
	var top: Vector2 = through[idx]
	var pts := PackedVector2Array([top])
	for k in range(terraces.size()):
		var t: PackedVector2Array = terraces[k]
		var e: int = 0 if end < 0.5 else t.size() - 1
		var p: Vector2 = t[e]
		var want_x: float = top.x + inward * lean * absf(p.y - top.y)
		want_x = clampf(want_x, out.site.position.x + EDGE_INSET_M, out.site.end.x - EDGE_INSET_M)
		t[e] = Vector2(want_x, p.y)
		terraces[k] = t
		pts.append(t[e])
	# a riser whose top and bottom are the same point has nowhere to go
	if pts.size() >= 2 and pts[0].distance_to(pts[pts.size() - 1]) >= 4.0:
		out.roads.append(VillageSitePlanner._road(pts, &"street", out.spec.wealth))


## The way out to the fields: tracks off `low`, leaning off the fall line so a
## field track can climb at 30 %. On the plane that is TRACK_LEAN_DEG; on given
## ground each spot takes the least lean, to either side, whose track really
## stays a track there (the steeper the face, the further off the fall line),
## and a spot where none does has no track.
static func _field_tracks(out: VillagePlan, low: PackedVector2Array, down: float,
		ground: VillageTerrain = null, spots: Array = TRACK_SPOTS, keep_clear: Array[Vector2] = []) -> void:
	if low.size() < 2:
		return
	for f in spots:
		var x: float = lerpf(low[0].x + CROSS_CLEAR_M, low[low.size() - 1].x - CROSS_CLEAR_M, float(f))
		var start := Vector2(x, VillageLotPlanner._polyline_y_at_x(low, x))
		if _near_any(start, keep_clear, TRACK_CLEAR_M):
			continue
		var side: float = 1.0 if f < 0.5 else -1.0
		var leans: Array = [TRACK_LEAN_DEG]
		if ground != null:
			leans = [TRACK_LEAN_DEG]
			var l := TRACK_LEAN_DEG + 5.0
			while l <= 75.0:
				leans.append(l)
				l += 5.0
		var placed := false
		for lean_deg in leans:
			for sgn in ([side, -side] if ground != null else [side]):
				var dir := Vector2(-tan(deg_to_rad(lean_deg)) * sgn, down).normalized()
				var t := INF
				if dir.x > 1e-9:
					t = minf(t, (out.site.end.x - start.x) / dir.x)
				elif dir.x < -1e-9:
					t = minf(t, (out.site.position.x - start.x) / dir.x)
				if dir.y > 1e-9:
					t = minf(t, (out.site.end.y - start.y) / dir.y)
				elif dir.y < -1e-9:
					t = minf(t, (out.site.position.y - start.y) / dir.y)
				if not is_finite(t) or t < 8.0:
					continue
				var end: Vector2 = start + dir * t
				if not VillageMeasure.on_boundary(out.site, end):
					continue
				var pts := PackedVector2Array([start, end])
				if ground != null and VillageRoadRouter.grade_of(ground, pts) > RISER_PICK_GRADE:
					continue
				out.roads.append(VillageSitePlanner._road(pts, &"track", out.spec.wealth))
				placed = true
				break
			if placed:
				break


## How many of the steep sites' bands the plan's body misses (none measured counts
## as a miss).
static func band_faults(plan: VillagePlan) -> int:
	var m: Dictionary = VillageShape.measure(plan)
	var misses := 0
	for row in [["elongation", BAND_ELONGATION], ["street_contour_share", BAND_CONTOUR],
			["elev_span_m", BAND_SPAN_M], ["steps_ways", BAND_STEPS]]:
		var v: Variant = m.get(row[0])
		var band: Vector2 = row[1]
		if v == null or float(v) < band.x or float(v) > band.y:
			misses += 1
	return misses


## True when a hillside's common is fronted by less of its edge than the place
## check wants: the through road's homes then stand beside it.
static func common_wants_homes(plan: VillagePlan) -> bool:
	if plan.spec.form != &"hillside" or plan.ground == null or plan.commons.is_empty():
		return false
	var want: float = VillagePlaceCheck.FRONTED_SHARE
	if plan.spec.population < VillageSpec.HAMLET_POPULATION:
		want = VillagePlaceCheck.FRONTED_SHARE_HAMLET
	return plan.buildings.size() >= 3 and VillagePlaceCheck.fronted_share(plan) < want


static func _near_any(p: Vector2, points: Array[Vector2], within: float) -> bool:
	for q in points:
		if p.distance_to(q) < within:
			return true
	return false


## The site cut that puts a gate by the tavern, or Vector2.ZERO when it needs
## none: (x_lo, x_hi) in the plan's frame, the west end brought in to
## `gate_m` from it, the east left open. (gate_m 0: only whether a cut is wanted.)
static func site_crop(plan: VillagePlan, gate_m: float) -> Vector2:
	if plan.spec.form != &"hillside" or plan.ground == null:
		return Vector2.ZERO
	var gates: Array[Vector2] = VillageMeasure.gates(plan)
	var worst := 0.0
	var worst_x := 0.0
	for i in VillageMeasure.shops_of(plan, &"tavern"):
		var fm: Vector2 = VillageMeasure.front_mid(plan.buildings[i])
		var near := INF
		for g in gates:
			near = minf(near, g.distance_to(fm))
		if near > worst:
			worst = near
			worst_x = fm.x
	if worst <= TAVERN_NEAR_M:
		return Vector2.ZERO
	# the table puts the tavern at the WEST gate (upwind of the smithy)
	return Vector2(worst_x - gate_m, INF)


## `line` with y eased by EASE_PASSES passes of [1 2 1] over its interior,
## except the pinned vertex and the two ends (a riser takes those).
static func _ease(line: PackedVector2Array, pinned: int) -> PackedVector2Array:
	var out := line.duplicate()
	for _pass in range(EASE_PASSES):
		var prev := out.duplicate()
		for i in range(1, out.size() - 1):
			if i == pinned:
				continue
			out[i] = Vector2(prev[i].x, (prev[i - 1].y + 2.0 * prev[i].y + prev[i + 1].y) * 0.25)
	return out


## Where a stepped cross-lane from `a` on `upper` meets `lower`: straight down
## (a.x) when its stair's treads are deep enough there, else the column of
## `through` (the terraces share its columns) in [lo, hi] nearest a.x, `hand`'s
## side first, whose stair is, and which meets both lines at JUNCTION_MIN_DEG
## or more. With none, the column whose stair is least shallow.
static func _cross_foot(ground: VillageTerrain, through: PackedVector2Array,
		upper: PackedVector2Array, lower: PackedVector2Array, a: Vector2,
		lo: float, hi: float, hand: float) -> float:
	var best_x: float = a.x
	var best_go: float = -INF
	var cands: Array[float] = [a.x]
	var cols: Array[float] = []
	for p in through:
		if p.x >= lo - 1e-6 and p.x <= hi + 1e-6 and absf(p.x - a.x) > 1e-3:
			cols.append(p.x)
	cols.sort_custom(func(u: float, v: float) -> bool:
		var du: float = absf(u - a.x) + (0.0 if signf(u - a.x) == hand else 0.5)
		var dv: float = absf(v - a.x) + (0.0 if signf(v - a.x) == hand else 0.5)
		return du < dv)
	cands.append_array(cols)
	var lines: Array[PackedVector2Array] = [upper, lower]
	for xb in cands:
		var b := Vector2(xb, VillageLotPlanner._polyline_y_at_x(lower, xb))
		var pts := PackedVector2Array([a, b])
		if xb != a.x and not _squarely(pts, lines):
			continue
		var go: float = stair_going(ground, a, b, upper, lower)
		if go >= CROSS_GOING_M:
			return xb
		if go > best_go:
			best_go = go
			best_x = xb
	return best_x


## The shallowest inner tread of a stair from `a` to `b` between two street
## beds, as `VillageGroundSurface` would lay it: the ground's height every
## STATION, smoothed; level with the line's bed (its height where the stair
## meets it) inside each street's ribbon, the step to the ground eased over
## JUNCTION_TAPER outside it; then `treads_of`. A lane on a 54 % face is too
## steep for 0.15 m risers on 0.28 m goings, and the eased step at a junction
## makes it steeper there than the face's grade says.
static func stair_going(ground: VillageTerrain, a: Vector2, b: Vector2,
		upper: PackedVector2Array, lower: PackedVector2Array) -> float:
	var length: float = a.distance_to(b)
	var n: int = maxi(2, int(ceil(length / VillageGroundSurface.STATION)))
	var raw := PackedFloat32Array()
	var s := PackedFloat32Array()
	var inside := PackedInt32Array()
	var half: float = float(VillageSitePlanner.ROAD_CLASSES[&"street"]["width"]) * 0.5 \
		+ float(VillageSitePlanner.ROAD_CLASSES[&"street"]["verge"])
	for m in range(n + 1):
		var p: Vector2 = a.lerp(b, float(m) / float(n))
		s.append(length * float(m) / float(n))
		raw.append(ground.height_at(p))
		var hit := -1
		if _dist_to_line(p, upper) <= half:
			hit = 0
		elif _dist_to_line(p, lower) <= half:
			hit = 1
		inside.append(hit)
	var h := PackedFloat32Array()
	h.resize(raw.size())
	for k in range(raw.size()):
		var sum := 0.0
		var cnt := 0
		for m in range(maxi(0, k - VillageGroundSurface.SMOOTH_STATIONS), mini(raw.size(), k + VillageGroundSurface.SMOOTH_STATIONS + 1)):
			sum += raw[m]
			cnt += 1
		h[k] = sum / float(cnt)
	var beds := [h[0], h[h.size() - 1]]
	var offset := PackedFloat32Array()
	offset.resize(h.size())
	offset.fill(0.0)
	for k in range(h.size() - 1):
		for pair in [[k, k + 1], [k + 1, k]]:
			var i: int = pair[0]
			var j: int = pair[1]
			if inside[i] < 0 or inside[j] >= 0:
				continue
			var delta: float = float(beds[inside[i]]) - h[i]
			for m in range(h.size()):
				var away: float = (s[m] - s[j]) * (1.0 if j > i else -1.0)
				if inside[m] >= 0 and away < 0.0:
					offset[m] += delta
				elif away >= 0.0 and away < VillageGroundSurface.JUNCTION_TAPER:
					offset[m] += delta * (1.0 - away / VillageGroundSurface.JUNCTION_TAPER)
	for k in range(h.size()):
		h[k] += offset[k]
	var ts: Array[Dictionary] = VillageGroundSurface.treads_of(s, h)
	var go := INF
	for k in range(1, ts.size() - 1):
		if float(ts[k]["s0"]) > 0.0 and float(ts[k]["s1"]) < length:
			go = minf(go, float(ts[k]["s1"]) - float(ts[k]["s0"]))
	return go


static func _dist_to_line(p: Vector2, line: PackedVector2Array) -> float:
	var d := INF
	for i in range(line.size() - 1):
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])))
	return d


## The x of `line`'s vertex nearest `x`.
static func _column_near(line: PackedVector2Array, x: float) -> float:
	var best: float = line[0].x
	for p in line:
		if absf(p.x - x) < absf(best - x):
			best = p.x
	return best


## True where the road check's bend rule (turn per 20 m, bend radius) fails at
## vertex `i` of `pts`.
static func _bends_badly(pts: PackedVector2Array, i: int) -> bool:
	var turns: PackedFloat32Array = Poly.turns(pts)
	var run: float = (pts[i].distance_to(pts[i - 1]) + pts[i].distance_to(pts[i + 1])) / 2.0
	var deg: float = rad_to_deg(absf(turns[i - 1]))
	if deg <= 1.0:
		return false
	if deg * 20.0 / maxf(run, 0.01) > BEND_DEG_PER_20M:
		return true
	return Poly.bend_radius(pts[i - 1], pts[i], pts[i + 1]) < BEND_RADIUS_M


## Terrace `r`'s bends eased where the road check would refuse them: the
## vertices round a bad one (but not a junction, where another way is
## attached) move halfway to their neighbours' middle, repeatedly.
static func _repair_bends(out: VillagePlan, r: int, line: PackedVector2Array) -> PackedVector2Array:
	var pts := line.duplicate()
	for _round in range(60):
		var bad := -1
		for i in range(1, pts.size() - 1):
			if _bends_badly(pts, i):
				bad = i
				break
		if bad < 0:
			break
		for i in range(maxi(1, bad - 2), mini(pts.size() - 1, bad + 3)):
			if _is_junction(out, r, pts[i]):
				continue
			var mid: Vector2 = (pts[i - 1] + pts[i + 1]) * 0.5
			pts[i] = pts[i].lerp(Vector2(pts[i].x, mid.y), 0.5)
	return pts


static func _is_junction(out: VillagePlan, r: int, p: Vector2) -> bool:
	for j in range(out.roads.size()):
		if j == r:
			continue
		for q in out.roads[j]["points"]:
			if q.distance_to(p) < 0.05:
				return true
	return false


## `points` cut to the x range [x0, x1], with the crossing points
## interpolated; fewer than two points means the range misses it.
static func _trim_x(points: PackedVector2Array, x0: float, x1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(points.size()):
		var p: Vector2 = points[i]
		if p.x >= x0 and p.x <= x1:
			out.append(p)
		if i + 1 < points.size():
			var q: Vector2 = points[i + 1]
			for edge_x: float in [x0, x1]:
				if (p.x - edge_x) * (q.x - edge_x) < 0.0:
					var t: float = (edge_x - p.x) / (q.x - p.x)
					out.append(Vector2(edge_x, lerpf(p.y, q.y, t)))
	# keep the polyline's order and drop points outside the range
	var kept := PackedVector2Array()
	for p in out:
		if p.x >= x0 - 1e-6 and p.x <= x1 + 1e-6:
			kept.append(p)
	return kept


## `points` with a vertex at x (split on its segment), returned.
static func _insert_at_x(points: PackedVector2Array, x: float) -> PackedVector2Array:
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		if (a.x - x) * (b.x - x) <= 0.0 and absf(b.x - a.x) > 1e-9:
			var t: float = (x - a.x) / (b.x - a.x)
			var p := Vector2(x, lerpf(a.y, b.y, t))
			if p.distance_to(a) <= 1e-6 or p.distance_to(b) <= 1e-6:
				return points
			var out := points.duplicate()
			out.insert(i + 1, p)
			return out
	return points


# -------------------------------------------------------------- the households

## The lot planner's hook (cut_measured): the households are distributed over
## the terraces, not all put on the through road. Left to itself the cutter
## fills the road nearest the common and the village stays a one-street row --
## the very thing this form exists to replace -- and its houses span one
## terrace instead of the whole hillside. Each home gets a slot on a level
## (the through road first, then each terrace), round robin, the biggest
## nearest the common (the wealth gradient), and is cut the lot nearest it.
static func assign_jobs(plan: VillagePlan, jobs: Array[Dictionary]) -> void:
	if plan.spec.form != &"hillside" or plan.roads.is_empty():
		return
	var homes: Array[Dictionary] = []
	for job in jobs:
		var rq: BuildingRequest = job["request"]
		if rq.kind == &"shop" and rq.purpose == &"tavern" and plan.ground != null:
			# by a gate, at either end of the road (the table says the west one)
			job["siting"] = {"road": &"through", "insists": true, "toward": &"gate"}
		if job["class"] in [&"cottage", &"townhouse", &"farm"]:
			homes.append(job)
	if homes.is_empty():
		return
	homes.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var ax: float = VillageLotPlanner._floor_area(x)
		var ay: float = VillageLotPlanner._floor_area(y)
		if absf(ax - ay) > 0.01:
			return ax > ay
		return int(x["order"]) < int(y["order"]))
	var through: Array[int] = plan.roads_of_class(&"through")
	var levels: Array[int] = []
	if not through.is_empty():
		levels.append(through[0])
	for r in range(plan.roads.size()):
		if (plan.roads[r] as Dictionary).has("terrace"):
			levels.append(r)
	if levels.size() < 2:
		return
	# how many homes each level carries (LEVEL_WEIGHTS: the road and the lowest
	# terrace, the longest lines of frontage with the most ground behind them, the
	# most), every level at least one; the shallow profile has one row of lots less
	# below the lowest terrace and its weights say so (LEVEL_WEIGHTS_SHALLOW). The
	# split that keeps the body's span, elongation and contour share inside the
	# steep sites' bands on the plane, Manarola, Masouleh and Rocamadour
	var weights: Array = LEVEL_WEIGHTS
	if bool(plan.roads[0].get("shallow", false)):
		weights = LEVEL_WEIGHTS_SHALLOW
	var total_w := 0.0
	for j in range(levels.size()):
		total_w += float(weights[mini(j, weights.size() - 1)])
	var counts: Array[int] = []
	var given := 0
	for j in range(levels.size()):
		var c: int = maxi(1, int(floor(float(homes.size()) * float(weights[mini(j, weights.size() - 1)]) / total_w)))
		counts.append(c)
		given += c
	var j2 := 0
	while given < homes.size():
		counts[j2 % levels.size()] += 1
		given += 1
		j2 += 1
	while given > homes.size():
		var jj: int = levels.size() - 1
		while jj > 0 and counts[jj] <= 1:
			jj -= 1
		counts[jj] -= 1
		given -= 1
	var filled: Array[int] = []
	filled.resize(levels.size())
	filled.fill(0)
	for i in range(homes.size()):
		# the biggest home to the level with the most room left, upper first
		var lv := 0
		var best_room := -1
		for j in range(levels.size()):
			var room: int = counts[j] - filled[j]
			if room > best_room:
				best_room = room
				lv = j
		var r: int = levels[lv]
		var pts: PackedVector2Array = plan.roads[r]["points"]
		var rank: int = filled[lv]
		filled[lv] += 1
		# staggered from the lowest level up (so its homes stand clear of the
		# field tracks off it): a chain of homes 45 m apart across the levels
		var t: float = (float(rank) + 0.2 + 0.5 * float((levels.size() - 1 - lv) % 2)) / float(counts[lv])
		var x: float = lerpf(pts[0].x + SLOT_END_M, pts[pts.size() - 1].x - SLOT_END_M, clampf(t, 0.0, 1.0))
		var around: bool = lv == 0 and not plan.commons.is_empty() and bool(homes[i].get("around_common", false))
		if around:
			var cr: Rect2 = Poly.bounding_rect(plan.commons[0]["poly"])
			var reach: float = cr.size.x * 0.5 + AROUND_LOT_FRONT_M
			var offs: Array = [reach, -reach, 0.0]
			x = clampf(cr.get_center().x + float(offs[mini(rank, AROUND_MAX - 1)]), pts[0].x + SLOT_END_M, pts[pts.size() - 1].x - SLOT_END_M)
		var y: float = VillageLotPlanner._polyline_y_at_x(pts, x)
		var side: float = 1.0 if rank % 2 == 0 else -1.0
		homes[i]["near_point"] = Vector2(x, y + side * 10.0)
		homes[i]["siting"] = VillageLotPlanner.SITING_DEFAULT

