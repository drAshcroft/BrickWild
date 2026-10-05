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
	&"path": {"width": 1.2, "verge": 0.7, "surface": ["trodden", "trodden", "stones"]},
	&"track": {"width": 3.0, "verge": 0.0, "surface": ["dirt", "dirt", "dirt"]},
}

## The forms this planner knows. Everything else is VIL-006 and later.
const FORMS_SUPPORTED: Array[StringName] = [&"street", &"green", &"crossroads",
	&"round", &"strand", &"planted", &"gate"]

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

## Two junctions closer than this are one junction with a kink (§5, and the
## road check's JUNCTION_APART). A ring of chords round a common is only
## drawn when its chords are longer.
const JUNCTION_MIN_SPACING_M := 8.0

const COMMON_MIN_AREA := 150.0
const HAMLET_COMMON_AREA := 30.0
const HAMLET_POPULATION := 25
const WELL_PLOT_SIDE := 5.6     ## the hamlet's common shrunk to the well: 31.4 m^2
## Clear metres between the road's verge and the common. ZERO: §3 calls the
## common "a widening of the road", and a metre and a half of ground that is
## neither road nor common nor lot is a moat -- VIL-016's walk grid takes
## roads, verges, lots and the common as floor and nothing else, so the well
## on a hamlet's little green could not be got at from the road at all.
const COMMON_ROAD_GAP := 0.0

const GREEN_MIN_W := 18.0
const GREEN_MIN_H := 12.0
const GREEN_SIDE_CLEAR := 4.0   ## from the green's edge to the ring street's centreline

const LANDMARK_AREA := 240.0    ## a church and its churchyard
const LANDMARK_AREA_SMALL := 144.0  ## a shrine's, where the population has not earned a church
const LANDMARK_GAP := 3.0

## How many back lanes a form lays: one per this many households, within
## these bounds, and no two closer than LANE_PITCH along the through road.
## See _back_lanes -- a farm can only satisfy §9.4's `farms outside` on a
## lane or at the very end of the through road, so lanes are what a farming
## village is short of.
const HOUSEHOLDS_PER_LANE := 2
const MAX_BACK_LANES := 8
## How far apart two back lanes have to be. A farm lot is about twenty-five
## metres deep and takes that depth PERPENDICULAR to its lane, so two lanes
## closer than about fifty metres leave no room for a farm on the ground
## between them -- every candidate lot overlaps the next lane's ribbon, no
## lot is cut, and `_trim_lanes` then takes the empty lanes up again. Eight
## lanes at nine metres gave a village with no lanes at all.
const LANE_PITCH := 50.0
## Where a field track may leave the through road, tried in this order.
##
## The quarter points first, because that is where a track has the site's
## whole depth to run out through and a farm on it still has ground either
## side; then progressively nearer the ends, which is where one has to go
## when the common and its churchyard have taken the middle. Ends-first put
## the tracks in the corners, where the ground beside them runs out and the
## farms went back on the through road.
const TRACK_SPOTS := [0.25, 0.75, 0.12, 0.88, 0.38, 0.62, 0.06, 0.94, 0.5]

const LANE_LENGTH := 22.0
const LANE_MIN_LENGTH := 12.0
## The longest a field track runs. Effectively uncapped: `_stub` clamps it to
## the site boundary, and reaching the boundary is what makes it a way out to
## the fields rather than a cul-de-sac.
const LANE_MAX_LENGTH := 400.0
const JUNCTION_EPS := 0.5       ## two road vertices this close are the same junction


## The whole of VIL-003: ground, through road, common, landmark slot, then
## the form's streets and lanes. Returns a fresh `VillagePlan`; `spec` is not
## modified. An unsupported form returns a plan with the site and nothing
## else, so callers can tell "not mine" from "failed".
static func plan(spec: VillageSpec, extra_lanes := 0, site_scale := 1.0,
		minimum_depth := 0.0, shore_depth := 0.0) -> VillagePlan:
	var out := VillagePlan.new(spec)
	if spec == null or not spec.valid():
		push_error("VillageSitePlanner: invalid spec")
		return out
	if spec.form == &"":
		push_error("VillageSitePlanner: spec.generate() has not been called")
		return out
	out.site = site_rect(spec)
	if spec.form == &"round":
		minimum_depth = maxf(minimum_depth, 2.0 * (6.0 + _round_ring_radius(10.5)
			+ _ring_half() + LANDMARK_GAP + RING_LANDMARK_DEPTH + SITE_MARGIN_M + 0.25))
	if minimum_depth > out.site.size.y:
		var depth := minf(minimum_depth, SITE_MAX_SIDE)
		out.site = Rect2(Vector2(out.site.position.x, -depth * 0.5), Vector2(out.site.size.x, depth))
	if site_scale > 1.0:
		# More ground when the lot planner could not house everyone on the
		# frontage the form gave it (VIL-006), grown about the centre and
		# never past the cap -- but ALONG THE ROAD ONLY.
		#
		# A village that outgrows itself gets longer, not wider: the frontage
		# it was short of is on the through road, and stretching across the
		# road adds ground with no road on it. Squaring it up also cost a
		# third of the density -- a 1.3 scale is 1.69 times the area both
		# ways and 1.3 times along one -- and §9.1's `density` rule, at least
		# 5 % built, is what noticed (VIL-012).
		var w: float = minf(out.site.size.x * site_scale, SITE_MAX_SIDE)
		var h: float = out.site.size.y
		out.site = Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))
	if spec.compact_display:
		_plan_compact(out, spec)
		return out
	if not (spec.form in FORMS_SUPPORTED):
		return out

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("site|%d|%s" % [spec.seed, spec.form])

	# 1. the road that goes through, before anything else
	var through: PackedVector2Array = _through_road(out.site, spec, rng)
	out.roads.append(_road(through, &"through", spec.wealth))
	if spec.form == &"strand":
		# The shore row's church envelope needs inland depth beyond the common.
		# Extend only that boundary after the road is fixed: the through road,
		# common and coast retain their sampled coordinates, while the lot
		# cutter gets honest ground for the measured landmark bounds.
		const STRAND_INLAND_GROW := 18.0
		out.site = Rect2(Vector2(out.site.position.x, out.site.position.y - STRAND_INLAND_GROW),
			Vector2(out.site.size.x, out.site.size.y + STRAND_INLAND_GROW))

	# 2. the common and the form's characteristic road graph
	match spec.form:
		&"green":
			_plan_green(out, spec, through)
		&"crossroads":
			_plan_crossroads(out, spec, through, rng)
		&"round":
			_plan_round(out, spec, through)
		&"strand":
			_plan_strand(out, spec, through, shore_depth)
		&"planted":
			_plan_planted(out, spec, through)
		&"gate":
			_plan_gate(out, spec, through, rng)
		_:
			_plan_street(out, spec, through, rng)
	# Authored forms may move the curved through route relative to their
	# common. Any extra lanes must join that final route, not its old vertices.
	through = out.roads[0]["points"]
	# 3. more frontage when the lot planner asks for it (VIL-006): back lanes
	# off the through road, on the side away from the common first, at the
	# spots the form did not take
	# A strand is deliberately one buildable row behind the shore road.  Adding
	# generic back lanes on the retry path would cut through the coast and turn
	# the row into a second village; the lot planner instead grows frontage along
	# the road when it needs more houses.
	if spec.form not in [&"strand", &"planted"]:
		_extra_lanes(out, spec, through, extra_lanes)
	# VIL-018 water is authored before lot cutting, so lots can avoid the
	# polygon and every later bridge/ford check reads the same geometry. Strand
	# owns a deliberately shifted coast rectangle above; preserve it exactly.
	if spec.water != &"none" and spec.form != &"strand":
		var water_plan: Dictionary = VillageWaterPlan.build(spec, out.site,
			out.roads, out.commons)
		for water in water_plan["water"]:
			out.water.append(water)
	out.water_crossings = VillageWaterPlan.crossings(out.water, out.roads)
	return out


## Lanes the form did not lay, added in a fixed order so a plan asked for N
## of them is the same plan every time. Each is a perpendicular stub off the
## through road, clear of the common, as long as the site allows (the lot
## planner trims it back to its last lot).
const EXTRA_LANE_LENGTH := 36.0
const EXTRA_LANE_SPOTS := [0.18, 0.82, 0.42, 0.58, 0.08, 0.92, 0.3, 0.7, 0.5, 0.25, 0.75]

static func _extra_lanes(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		wanted: int) -> void:
	if wanted <= 0:
		return
	var site: Rect2 = out.site
	var common_side: float = 1.0      # the common is north of the road in both forms
	var common_x := Vector2(-INF, INF)
	if not out.commons.is_empty():
		var cr: Rect2 = Poly.bounding_rect(out.commons[0]["poly"])
		common_x = Vector2(cr.position.x - 10.0, cr.end.x + 10.0)
	var added := 0
	for pass_side in [-common_side, common_side]:
		for f in EXTRA_LANE_SPOTS:
			if added >= wanted:
				return
			var x: float = site.position.x + site.size.x * float(f)
			if pass_side > 0.0 and x > common_x.x and x < common_x.y:
				continue
			var idx: int = _vertex_near_x(through, x)
			var start: Vector2 = through[idx]
			var taken := false
			for road in out.roads:
				if road["class"] == &"through":
					continue
				var pts: PackedVector2Array = road["points"]
				if pts[0].distance_to(start) < 12.0 or pts[pts.size() - 1].distance_to(start) < 12.0:
					taken = true
			if taken:
				continue
			var lane: PackedVector2Array = _stub(through, idx, pass_side, EXTRA_LANE_LENGTH, site)
			if lane.size() != 2:
				continue
			# not across the common, nor the landmark slot
			var ribbon: PackedVector2Array = Poly.ribbon(lane, 1.75)
			var blocked := false
			for c in out.commons:
				if VillageLotPlanner.overlap_area(ribbon, c["poly"]) > 0.05:
					blocked = true
			if out.landmark_reserved() and VillageLotPlanner.overlap_area(ribbon, out.landmark_site["poly"]) > 0.05:
				blocked = true
			if blocked:
				continue
			out.roads.append(_road(lane, &"lane", spec.wealth))
			added += 1


## The ground the village stands on: a square centred on the origin, sized so
## the built area lands in the middle of §9.1's density band. Deterministic,
## and independent of the road -- the road is laid inside it.
static func site_rect(spec: VillageSpec) -> Rect2:
	if spec.compact_display:
		var depth: float = 80.0 if _compact_has_landmark(spec) else 64.0
		return Rect2(Vector2(-33.0, -depth * 0.5), Vector2(66.0, depth))
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
	# Retry sites grow along the road only. Moving the road by that new width
	# consumed the unchanged southern building row (and eventually left the
	# site). Its lateral offset belongs to the site's depth, not its length.
	var offset: float = -0.12 * site.size.y if spec.form == &"green" else 0.0
	var samples: int = maxi(THROUGH_MIN_SAMPLES, int(ceil(length / THROUGH_SAMPLE_M)))
	var pts := PackedVector2Array()
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var x: float = site.position.x + length * t
		var y: float = offset + a1 * sin(PI * t) + a2 * sin(TAU * t)
		pts.append(Vector2(x, y))
	# The bend grows with the road's LENGTH, and a site
	# stretched along its road (VIL-012) keeps its depth: a 315 m by 90 m site
	# carried its through road 54 m off the middle, out of the ground the walk
	# grid covers, and nobody could arrive (EVAL-C11). Keep the whole road, with
	# its verges and the site margin, inside the site; a road that already fits
	# is untouched.
	var half_road: float = float(ROAD_CLASSES[&"through"]["width"]) * 0.5 		+ float(ROAD_CLASSES[&"through"]["verge"])
	var room: float = site.size.y * 0.5 - half_road - SITE_MARGIN_M
	var reach := 0.0
	for p in pts:
		reach = maxf(reach, absf(p.y))
	if reach > room and room > 0.0:
		var squeeze: float = room / reach
		for i in range(pts.size()):
			pts[i].y *= squeeze
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
	# A hamlet's well plot is 5.6 m across. Its approach path leaves the through
	# road at a real vertex, and a path that slants in from a vertex five metres
	# off the plot's axis puts its ribbon corner in the well's own floor, so the
	# well is pushed off the centre and out of the path's reach. Put the plot on
	# the vertex: the path runs straight in and the well stands at its end.
	if hamlet:
		mid = through[_vertex_near_x(through, 0.0)].x
	var rect: Rect2 = _rect_north_of(through, out.roads[0], mid, width, height, COMMON_ROAD_GAP)
	out.commons.append({"poly": Poly.from_rect(rect), "kind": &"common"})
	# A bowed road may touch the common only at one corner. That contact has
	# no pedestrian width after erosion, so give the well a real civic path.
	# The path stops a stride short of the well, on the line it was walking: from
	# a vertex off the plot's axis that line is slanted, and ending it straight
	# above the centre left its ribbon's corner in the well's own floor (the
	# well was pushed aside and out of the path's reach, EVAL-C11).
	var join: Vector2 = through[_vertex_near_x(through, mid)]
	var walk: Vector2 = (rect.get_center() - join).normalized()
	var approach := _road(PackedVector2Array([join, rect.get_center() - walk * 1.9]),
		&"path", spec.wealth)
	out.roads.append(approach)

	# The common's other three sides (VIL-012). Without them the common has
	# frontage on ONE edge -- the through road -- and §9.4's `common` rule,
	# which wants 60 % of its perimeter fronted, measured 57 %. A back street
	# round the far side is what a village does about that, and it is the
	# same shape the `green` form's ring already has.
	#
	# A street and not a lane, for a reason §9.2 states: a lane's endpoint has
	# to be on a street or a through road or at a lot, so a ring of three
	# lanes meeting each other is three dead ends by the road hierarchy's own
	# definition. A street may end on a street.
	var ring_y: float = _ring_street(out, spec, through, rect, site)

	# the landmark slot, BEFORE any lot: behind the common, fronting it, and
	# beyond the ring so the churchyard is not laid across the road that
	# fronts it.
	var behind_ring: float = -INF if ring_y == -INF else ring_y + _ring_half() + LANDMARK_GAP
	_reserve_landmark(out, spec, rect, site, behind_ring)

	_field_tracks(out, spec, through, site)


## Two roads cross at a real shared vertex.  The common sits in the north-east
## corner of the crossing so neither carriageway cuts it, while both roads
## still pass within the common's fifteen-metre frontage reach.
static func _plan_crossroads(out: VillagePlan, spec: VillageSpec,
		through: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var site: Rect2 = out.site
	var crossing: Vector2 = through[_vertex_near_x(through, site.get_center().x)]
	var centre := crossing
	var second := _axis_road(site, true, centre, rng)
	out.roads.append(_road(second, &"through", spec.wealth))
	# A small construction margin keeps the measured polygon above 150 m2
	# after float coordinates are translated to a seeded crossing.
	var common := Rect2(centre + Vector2(4.0, 4.0), Vector2(15.0, 10.1))
	common.position.x = minf(common.position.x, site.end.x - 4.0 - common.size.x)
	common.position.y = minf(common.position.y, site.end.y - 4.0 - common.size.y)
	out.commons.append({"poly": Poly.from_rect(common), "kind": &"common"})
	_reserve_landmark(out, spec, common, site)
	# Tracks belong outside the crossing; adding them here would turn a simple
	# four-way village into a star and would consume the inn's corner frontage.


## A circular common is a polygon, not a circle primitive, so all downstream
## checks and the renderer see the same GEO-001-style boundary.  One lane ends
## inside it; VillageRoadCheck treats that endpoint as a deliberate civic
## destination rather than a dead-end.
static func _plan_round(out: VillagePlan, spec: VillageSpec,
		through: PackedVector2Array) -> void:
	var site: Rect2 = out.site
	var centre := site.get_center() + Vector2(0.0, 6.0)
	var radius: float = minf(10.5, minf(10.5 + float(spec.households) * 0.08,
		minf(site.size.x, site.size.y) * 0.16))
	# Keep the seeded bend, but place it below the round common. A fixed
	# common over an unshifted positive bow put the approach backwards and
	# made its two ring junctions nearly parallel or only three metres apart.
	var through_half: float = float(out.roads[0]["width"]) * 0.5 + float(out.roads[0]["verge"])
	var target_y: float = centre.y - radius - through_half - 3.0
	var current_y: float = VillageLotPlanner._polyline_y_at_x(through, centre.x)
	through = _shift_points(through, Vector2(0.0, target_y - current_y))
	out.roads[0]["points"] = through
	var common := _circle_polygon(centre, radius, 16)
	out.commons.append({"poly": common, "kind": &"common"})
	var road_at_centre: Vector2 = through[_vertex_near_x(through, centre.x)]
	var approach := PackedVector2Array([road_at_centre,
		Vector2(centre.x, centre.y - radius * 0.55)])
	out.roads.append(_road(approach, &"lane", spec.wealth))
	var bounds := Poly.bounding_rect(common)
	# The circle's one civic lane is its entrance; a connected street loop gives
	# ordinary lots frontage on the rest of the perimeter without adding more
	# authored lanes to the round form.
	var ring_y: float = _ring_street(out, spec, through, bounds, site)
	var landmark_bottom: float = bounds.end.y + LANDMARK_GAP
	if ring_y != -INF:
		landmark_bottom = ring_y + _ring_half() + LANDMARK_GAP
	_reserve_landmark(out, spec, bounds, site, landmark_bottom)
	_field_tracks(out, spec, through, site)


## A strand's single row stands between its inland road and the shore.
## The measured row depth leaves the full native houses and a working bank
## on dry ground; a mill can reach water from its rear without crossing a road.
static func _plan_strand(out: VillagePlan, spec: VillageSpec,
		through: PackedVector2Array, measured_depth := 0.0) -> void:
	var site: Rect2 = out.site
	var shifted := _shift_points(through, Vector2(0.0, -4.0))
	out.roads[0]["points"] = shifted
	var road_min_y := INF
	var road_max_y := -INF
	for p in shifted:
		road_min_y = minf(road_min_y, p.y)
		road_max_y = maxf(road_max_y, p.y)
	var row_depth := measured_depth if measured_depth > 0.0 else 28.0
	var water_height: float = maxf(18.0, site.size.y * 0.20)
	var water_y: float = road_max_y + 4.5 + row_depth + 2.0
	var shore_end := water_y + water_height + 3.0
	if shore_end > site.end.y:
		out.site.size.y += shore_end - site.end.y
		site = out.site
	var water_rect := Rect2(Vector2(site.position.x + 4.0, water_y),
		Vector2(site.size.x - 8.0, water_height))
	out.water.append({"poly": Poly.from_rect(water_rect), "kind": &"coast"})
	var anchor_y: float = shifted[0].y
	var anchor_dx: float = absf(shifted[0].x - site.get_center().x)
	for p in shifted:
		var dx: float = absf(p.x - site.get_center().x)
		if dx < anchor_dx:
			anchor_dx = dx
			anchor_y = p.y
	var common_y: float = anchor_y + 4.5
	var common := Rect2(Vector2(site.get_center().x - 9.0, common_y), Vector2(18.0, 10.0))
	out.commons.append({"poly": Poly.from_rect(common), "kind": &"common"})
	var approach := _road(PackedVector2Array([Vector2(0.0, anchor_y),
		common.get_center() - Vector2(0.0, 1.9)]), &"path", spec.wealth)
	out.roads.append(approach)
	# The landmark can occupy the inland civic plot without creating a
	# second residential row. Its own service lane keeps its native door.
	var civic := Rect2(Vector2(common.position.x, anchor_y - 5.0), common.size)
	_reserve_strand_landmark(out, spec, civic, site)


## Rich planted villages get a square and a short rectangular street grid. The
## two horizontal streets are intentionally parallel; the side streets close
## the graph back to the through road without crossing the square.
static func _plan_planted(out: VillagePlan, spec: VillageSpec,
		through: PackedVector2Array) -> void:
	var site: Rect2 = out.site
	var centre := site.get_center()
	var square_side: float = minf(32.0, site.size.x * 0.24)
	# The through road fronts the square's south side. Pin its height at the
	# square rather than shifting its seed-dependent bow by a fixed amount.
	var at_centre: float = VillageLotPlanner._polyline_y_at_x(through, centre.x)
	through = _shift_points(through, Vector2(0.0, -square_side * 0.5 - 8.0 - at_centre))
	out.roads[0]["points"] = through
	var square := Rect2(centre - Vector2(square_side, square_side) * 0.5,
		Vector2(square_side, square_side))
	out.commons.append({"poly": Poly.from_rect(square), "kind": &"square"})
	var bottom: float = square.position.y - 38.0
	var top: float = square.end.y + 4.0
	var left_x: float = square.position.x - 4.0
	var right_x: float = square.end.x + 4.0
	# Exact offsets matter: snapping to a ten-metre road sample could put a
	# frontage beyond the fourteen-metre reach of the common's perimeter.
	var left_start := Vector2(left_x, VillageLotPlanner._polyline_y_at_x(through, left_x))
	var right_start := Vector2(right_x, VillageLotPlanner._polyline_y_at_x(through, right_x))
	var left_bottom := Vector2(left_start.x, bottom)
	var right_bottom := Vector2(right_start.x, bottom)
	var left_top := Vector2(left_start.x, top)
	var right_top := Vector2(right_start.x, top)
	var grid_half: float = maxf(48.0, site.size.x * 0.36)
	var grid_left := centre.x - grid_half
	var grid_right := centre.x + grid_half
	out.roads.append(_road(PackedVector2Array([left_start, left_bottom]), &"street", spec.wealth))
	out.roads.append(_road(PackedVector2Array([Vector2(grid_left, bottom), Vector2(grid_right, bottom)]), &"street", spec.wealth))
	# Close both sides of the planted grid.  Without these two connectors the
	# bottom and top streets are separate islands, and the side of the square
	# has no legal frontage.
	out.roads.append(_road(PackedVector2Array([left_start, left_top]), &"street", spec.wealth))
	out.roads.append(_road(PackedVector2Array([right_start, right_top]), &"street", spec.wealth))
	out.roads.append(_road(PackedVector2Array([Vector2(grid_left, top), Vector2(grid_right, top)]), &"street", spec.wealth))
	out.roads.append(_road(PackedVector2Array([right_start, right_bottom]), &"street", spec.wealth))
	# Continue the parallel streets beyond the square into two real blocks.
	# A square-only loop forced every household back onto an ever-longer
	# through road: technically a grid, visually another street village.
	for x in [grid_left, grid_right]:
		var junction := Vector2(x, VillageLotPlanner._polyline_y_at_x(through, x))
		out.roads.append(_road(PackedVector2Array([Vector2(x, bottom), junction]), &"street", spec.wealth))
		out.roads.append(_road(PackedVector2Array([junction, Vector2(x, top)]), &"street", spec.wealth))
	# A metre of green verge separates the street from the square. Bridge it
	# with a pedestrian approach: otherwise the walk grid correctly finds a
	# beautiful but inaccessible island containing the well and market.
	var approach := _road(PackedVector2Array([Vector2(left_x, centre.y),
		centre - Vector2(2.0, 0.0)]), &"path", spec.wealth)
	out.roads.append(approach)
	_reserve_landmark(out, spec, square, site, top + _ring_half() + LANDMARK_GAP)


## A pedestrian planted settlement. The native site planner owns this graph:
## two mildly bowed parallel streets provide four rows of measured lots.
## Width retries enlarge the street runs without enlarging the buildings.
static func _plan_compact(out: VillagePlan, spec: VillageSpec) -> void:
	var left := out.site.position.x
	var right := out.site.end.x
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("compact-site|%d" % spec.seed)
	var bend := rng.randf_range(0.65, 1.15)
	var left_front := Vector2(left + 2.0, -13.0 + bend * 2.0 / absf(left))
	var right_front := Vector2(right - 2.0, left_front.y)
	var left_back := Vector2(left + 2.0, 13.0 - bend * 0.7 * 2.0 / absf(left))
	var right_back := Vector2(right - 2.0, left_back.y)
	var front := PackedVector2Array([Vector2(left, -13.0), left_front,
		Vector2(0.0, -13.0 + bend), right_front, Vector2(right, -13.0)])
	var back := PackedVector2Array([left_back, Vector2(0.0, 13.0 - bend * 0.7), right_back])
	out.roads.append(_compact_road(front, &"through", spec))
	out.roads.append(_compact_road(back, &"street", spec))
	out.roads.append(_compact_road(PackedVector2Array([left_front, left_back]), &"street", spec))
	out.roads.append(_compact_road(PackedVector2Array([right_front, right_back]), &"street", spec))
	var common := Rect2(Vector2(-4.0, -3.0), Vector2(8.0, 6.0))
	out.commons.append({"poly": Poly.from_rect(common), "kind": &"square"})
	out.roads.append(_compact_road(PackedVector2Array([front[2], Vector2(0.0, -1.5)]), &"path", spec))
# Reserve church ground only when the programme earns a shrine or church.
	# Hamlets below that threshold need their frontage for households. The
	# full-size compact shrine also needs a real six-metre churchyard around
	# its measured walls, so leave enough width for both side clearances.
	if _compact_has_landmark(spec):
		var civic := Rect2(Vector2(-11.0, 16.0), Vector2(22.0, 22.0))
		out.landmark_site = {"poly": Poly.from_rect(civic), "kind": &"church",
			"front": PackedVector2Array([civic.position, civic.position + Vector2(civic.size.x, 0.0)])}


static func _compact_has_landmark(spec: VillageSpec) -> bool:
	for row in spec.programme:
		if row["kind"] in [&"shrine", &"church", &"temple"]:
			return true
	return false


static func _compact_road(points: PackedVector2Array, cls: StringName, spec: VillageSpec) -> Dictionary:
	var road := _road(points, cls, spec.wealth)
	var rule := road_rule(cls, spec)
	road["width"] = rule["width"]
	road["verge"] = rule["verge"]
	return road


## Effective geometry policy shared with native QA.
static func road_rule(cls: StringName, spec: VillageSpec) -> Dictionary:
	var rule: Dictionary = ROAD_CLASSES[cls]
	if not spec.compact_display:
		return rule
	rule = rule.duplicate()
	rule["width"] = 1.2 if cls == &"path" else 2.2
	rule["verge"] = 0.25
	return rule


static func density_max(spec: VillageSpec) -> float:
	return 0.55 if spec.compact_display else 0.30


static func common_min_area(spec: VillageSpec) -> float:
	if spec.compact_display: return 40.0
	return HAMLET_COMMON_AREA if spec.population < HAMLET_POPULATION else COMMON_MIN_AREA


## Gate villages keep the ordinary common and through road, but the manor's
## own lane is added by VillageLotPlanner once its measured footprint is
## known. Keeping that service lane in the lot planner is what guarantees the
## gate plan's head lot is wide enough for the actual keep/manor request.
static func _plan_gate(out: VillagePlan, spec: VillageSpec,
		through: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	_plan_street(out, spec, through, rng)
	# The lord's own lane and deep forecourt occupy the eastern head of the
	# village. Field tracks are authored before that measured lot exists, so
	# keep their exits on the western side instead of slicing through its site.
	for index in range(out.roads.size() - 1, 0, -1):
		var road: Dictionary = out.roads[index]
		if road["class"] == &"track" and road["points"][0].x > out.site.get_center().x:
			out.roads.remove_at(index)


static func _axis_road(site: Rect2, vertical: bool, centre: Vector2,
		rng: RandomNumberGenerator) -> PackedVector2Array:
	var span: float = site.size.y if vertical else site.size.x
	var samples: int = maxi(10, int(ceil(span / THROUGH_SAMPLE_M)))
	if samples % 2 == 1:
		samples += 1
	# The authored through road already supplies the form's bend.  A straight
	# secondary axis gives the crossroads a clean, inspectable junction at any
	# seeded crossing position and avoids a sharp turn where the roads meet.
	var amplitude: float = 0.0
	var out := PackedVector2Array()
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var along: float = (site.position.y if vertical else site.position.x) + span * t
		# Cubing the wave keeps the crossing's tangent nearly straight while
		# retaining a visible bow toward either site edge.
		var bend: float = amplitude * pow(sin(TAU * t), 3.0)
		out.append(Vector2(centre.x + bend, along) if vertical
			else Vector2(along, centre.y + bend))
	# The two through roads must share an actual vertex, not merely pass within
	# the junction tolerance. Pin the sample nearest the supplied crossing; the
	# zero-at-midpoint bend keeps the neighbouring segments smooth.
	var crossing_t: float = ((centre.y - site.position.y) / span) if vertical \
		else ((centre.x - site.position.x) / span)
	var crossing_i: int = clampi(int(round(crossing_t * samples)), 1, samples - 1)
	out[crossing_i] = centre
	return out


static func _shift_points(points: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + delta)
	return out


static func _circle_polygon(centre: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(sides):
		var a: float = TAU * float(i) / float(sides)
		out.append(centre + Vector2(cos(a), sin(a)) * radius)
	return out


## The tracks out to the fields: perpendicular stubs off the through road,
## running right out to the edge of the site (§5, and §8 "strip fields ...
## each touching a `track`").
##
## A `track` and not a `lane`, and the two road rules between them say why.
## §9.2's `hierarchy` requires every LANE endpoint to be on a street or a
## through road or at a lot -- the site boundary is none of those -- while
## its `dead_ends` rule exempts any endpoint ON the boundary and refuses a
## lane longer than forty metres that is not. A seventy-metre stub out to the
## fields is one or the other whichever class it is given, and a track is
## what it actually is.
##
## Both forms get them, and one per two households rather than always two
## (VIL-012). A lane is the only frontage that reaches OUT toward the edge:
## a lot on the through road stands its own depth back from it and no
## further, so on a site whose road runs down the middle every farm on it is
## dead centre between the two long edges, and §9.4's `farms outside` -- a
## farm within thirty metres of the edge, its yard to the fields -- cannot be
## met on the through road at all.
##
## THE SIDE IS CHOSEN BY WHICH HAS GROUND, not by which is away from the
## common. The through road is bowed and sits where the site planner put it,
## which on a `green` village is eighteen metres from the south edge and
## seventy from the north; lanes sent dutifully to the "far side from the
## common" ran off the site and were trimmed away again, leaving six farms of
## eight in the middle of the village. On the common's own side the lanes
## step round the common and the landmark, which is what `_extra_lanes`
## already does.
static func _field_tracks(out: VillagePlan, spec: VillageSpec,
		through: PackedVector2Array, site: Rect2) -> void:
	var lo := INF
	var hi := -INF
	for p in through:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var north: float = site.end.y - hi
	var south: float = lo - site.position.y
	var side: float = 1.0 if north > south else -1.0
	# clear of the common and its landmark when the lanes go their way
	var busy := Vector2(INF, -INF)
	if not out.commons.is_empty() and side > 0.0:
		var cr: Rect2 = Poly.bounding_rect(out.commons[0]["poly"])
		busy = Vector2(cr.position.x, cr.end.x)
		if out.landmark_reserved():
			var lr: Rect2 = Poly.bounding_rect(out.landmark_site["poly"])
			busy = Vector2(minf(busy.x, lr.position.x), maxf(busy.y, lr.end.x))
		busy += Vector2(-LANE_PITCH * 0.5, LANE_PITCH * 0.5)

	# As many as the households want, as many as the ground has room for at
	# LANE_PITCH apart. `- 1` because n lanes spread evenly over a span leave
	# n + 1 gaps: four lanes on 221 m sit 45 m apart, which is inside the
	# pitch, and the guard below then throws three of them away.
	var room: int = int((site.size.x - SITE_MARGIN_M * 2.0) / LANE_PITCH) - 1
	var lanes: int = clampi(mini(int(spec.households / HOUSEHOLDS_PER_LANE), room),
		1, MAX_BACK_LANES)
	# A lane runs as far toward the edge as the ground allows, because that is
	# the whole reason it exists: a farm takes the spot nearest the boundary
	# it can find, and a stub that stops twenty-two metres out on a
	# seventy-metre side leaves it in the middle of the village. `_trim_lanes`
	# cuts whatever is left over back to the last lot on it.
	# `_stub` clamps this to the boundary itself, per vertex -- the road is
	# bowed, so how far a stub has to run to reach the edge depends on which
	# vertex it leaves from and at what angle. Asking for the side's own
	# depth left every lane a few metres short of the edge, which is the
	# difference between a way out to the fields and a seventy-metre
	# cul-de-sac.
	var reach: float = LANE_MAX_LENGTH
	if (north if side > 0.0 else south) < LANE_MIN_LENGTH + SITE_MARGIN_M:
		return
	# Candidate positions from the OUTSIDE IN, alternating ends. Evenly
	# spaced positions do not survive: a street village's common sits mid-
	# road, and the span it and its churchyard take up swallowed every one of
	# three evenly spread candidates on seventeen of fifty seeds, leaving the
	# village no way out to its own fields. Working inward from the ends also
	# puts the first tracks where the farms want them.
	var added := 0
	for f in TRACK_SPOTS:
		if added >= lanes:
			break
		var x: float = site.position.x + site.size.x * f
		if x > busy.x and x < busy.y:
			continue
		var idx: int = _vertex_near_x(through, x)
		var lane: PackedVector2Array = _stub(through, idx, side, reach, site, true)
		if lane.size() != 2:
			continue
		# On the boundary, never past it. `_stub` aims at the edge along the
		# road's own normal and a bowed road's normal is not quite vertical,
		# so the last metre or two can land outside -- which every check that
		# holds the plan inside its site rightly refuses.
		lane = PackedVector2Array([lane[0], Vector2(
			clampf(lane[1].x, site.position.x, site.end.x),
			clampf(lane[1].y, site.position.y, site.end.y))])
		if lane[0].distance_to(lane[1]) < LANE_MIN_LENGTH:
			continue
		# Not on top of a track or lane already there. Those two only: the
		# pitch is what a farm lot needs between one and the next, and
		# measuring it against the ring STREET rejected every back way a
		# green village could have had.
		var taken := false
		for road in out.roads:
			if not road["class"] in [&"track", &"lane"]:
				continue
			var pts: PackedVector2Array = road["points"]
			if pts[0].distance_to(lane[0]) < LANE_PITCH:
				taken = true
		if not taken:
			out.roads.append(_road(lane, &"track", spec.wealth))
			added += 1


## What has to fit beyond the ring street for it to be worth laying: the
## churchyard slot it pushes out. Nothing more -- the landmark IS the lot
## that fronts the common across the ring, and a lot on the ring's outer side
## has its front edge seven and a half metres from the common's far edge,
## well inside §9.4's fourteen-metre reach. Asking for a whole further rank
## of lots as well took the ring away from every village small enough to
## need it most.
const RING_LANDMARK_DEPTH := 16.0
const RING_LOT_BAND := 0.0


## Half the ring street's carriageway plus its verge: the strip nothing may
## stand in, and what the common and the landmark are held clear of.
static func _ring_half() -> float:
	return float(ROAD_CLASSES[&"street"]["width"]) * 0.5 \
		+ float(ROAD_CLASSES[&"street"]["verge"])


## A tangent street arc around the far half of the common, closed at both ends
## by the through road itself.  A rectangular loop leaves the circle's
## diagonal arcs more than FRONTED_REACH from a lot front; the four chords
## below are an octagonal approximation whose inner road edge is tangent to
## the common.  Returns the far side y, or -INF when the site has no room.
static func _ring_street(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		common: Rect2, site: Rect2) -> float:
	var clear: float = _ring_half() + COMMON_ROAD_GAP
	var centre := common.get_center()
	var radius := maxf(common.size.x, common.size.y) * 0.5
	# A rectangular common reaches past the circle its longer side implies, to
	# its corners; a ring tangent to that circle cut across them (the street
	# form's two end chords overlapped the common by 3.5 m^2 on 17 of 50 seeds).
	# The gate form shares it. Its manor lane used to need the old, smaller
	# ring; the lot planner now grows the lord's site as it does for any manor
	# (plan_measured), and the manor is placed with the corrected ring (EVAL-C11).
	if spec.form == &"street" or spec.form == &"gate":
		radius = common.size.length() * 0.5
	# Chords cut inside their circumradius.  Offset the centreline by the
	# reciprocal of cos(22.5 degrees), so the inward road edge remains at the
	# common's radius even at the midpoint of each 45-degree chord.  Each chord
	# is a separate, connected street: the corners are real junctions rather
	# than a short polyline bend, and remain more than eight metres apart.
	var arc_radius: float = (radius + clear) / cos(PI / 8.0)
	if spec.form == &"round":
		arc_radius = _round_ring_radius(radius)
	var far_y: float = centre.y + arc_radius
	# A ring round a well plot is chords of four metres: junctions on top of
	# each other, and a street laid across the plot's own corners. A hamlet's
	# common is fronted on the through road alone; that is what a hamlet is.
	if spec.form != &"round" and 2.0 * arc_radius * sin(PI / 8.0) < JUNCTION_MIN_SPACING_M:
		return -INF
	# Room for the street, the landmark behind it AND a band of lots beyond
	# that -- not merely for the street itself.
	#
	# The band is the whole point. A back street the village cannot build on
	# is six metres of ground and a landmark pushed eight metres further out,
	# and on a ninety-metre site that is the difference between housing nine
	# households and housing three. So a small village keeps its single
	# frontage on the through road, and its common is fronted on one side;
	# a village with the ground gets the street and a common fronted all
	# round. §9.4's `common` rule is a warning on the ones that cannot.
	if far_y + _ring_half() + LANDMARK_GAP + RING_LANDMARK_DEPTH + RING_LOT_BAND \
			> site.end.y - SITE_MARGIN_M:
		return -INF
	# The endpoints must stand OUTSIDE the common, not merely near it: the through
	# road is sampled every ten metres and bends, so the nearest vertex to a
	# wanted x can be five metres the wrong side of it -- which laid the lane
	# through the green on seven of fifty street seeds.
	var ia: int = _vertex_outside_x(through, common.position.x - clear, -1.0)
	var ib: int = _vertex_outside_x(through, common.end.x + clear, 1.0)
	if ia < 0 or ib < 0 or ib - ia < 1:
		return -INF
	var west := centre + Vector2(-arc_radius, 0.0)
	var east := centre + Vector2(arc_radius, 0.0)
	if west.x < site.position.x + SITE_MARGIN_M or east.x > site.end.x - SITE_MARGIN_M:
		return -INF
	var arc := PackedVector2Array()
	for i in range(5):
		var angle: float = PI - PI * float(i) / 4.0
		arc.append(centre + Vector2(cos(angle), sin(angle)) * arc_radius)
	if spec.form == &"round":
		# A broad northern frontage gives the civic landmark a real address.
		# Two short diagonal tips cannot receive a measured stepped temple:
		# its straight front otherwise cuts across the neighbouring road bend.
		var shoulder := arc_radius * cos(PI / 4.0)
		arc = PackedVector2Array([west, centre + Vector2(-shoulder, arc_radius),
			centre + Vector2(shoulder, arc_radius), east])
	out.roads.append(_road(PackedVector2Array([through[ia], west]), &"street", spec.wealth))
	for i in range(arc.size() - 1):
		out.roads.append(_road(PackedVector2Array([arc[i], arc[i + 1]]), &"street", spec.wealth))
	out.roads.append(_road(PackedVector2Array([east, through[ib]]), &"street", spec.wealth))
	return far_y


## Straight flank frontages need room for actual shop widths between their
## two junctions. A ring drawn tight against the circular green provides
## attractive corners but no legal frontage between the road ribbons.
static func _round_ring_radius(common_radius: float) -> float:
	return maxf((common_radius + _ring_half() + COMMON_ROAD_GAP) / cos(PI / 8.0),
		common_radius + _ring_half() + 5.0)


## No road or lot within this of the site edge, matching the lot planner's own
## SITE_MARGIN.
const SITE_MARGIN_M := 2.0


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
	# Snapping can leave less than the minimum green width between the two
	# junctions. Move the junctions too, rather than extending the common
	# through its eastern ring road while leaving that road where it was.
	while through[ib].x - through[ia].x < want_w + GREEN_SIDE_CLEAR * 2.0:
		if ia > 0:
			ia -= 1
		elif ib < through.size() - 1:
			ib += 1
		else:
			break
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
	# The common clears the highest part of a bowed road, leaving a gap at
	# its centre. Give the well a real walking approach across that gap.
	var join: Vector2 = through[_vertex_near_x(through, rect.get_center().x)]
	var walk := (rect.get_center() - join).normalized()
	out.roads.append(_road(PackedVector2Array([join, rect.get_center() - walk * 1.9]),
		&"path", spec.wealth))

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
	_field_tracks(out, spec, through, site)


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
	# The road between two samples is higher than the lower of them: take the
	# road where the rectangle's own edges stand, not only the samples near it.
	for edge_x in [left, right]:
		road_top = maxf(road_top, VillageLotPlanner._polyline_y_at_x(points, edge_x))
	if road_top == -INF:
		road_top = 0.0
	var bottom: float = road_top + float(road["width"]) * 0.5 + float(road["verge"]) + gap
	return Rect2(Vector2(left, bottom), Vector2(width, height))


## §2.1: the landmark slot is taken before any house lot. It goes behind the
## common, fronting it, so the church looks over the green from every side of
## it. `front` is the edge that faces the common.
## A strand puts water beyond the through road, so its church or shrine must
## sit on the inland side of the common rather than in the coast band.  The
## explicit bottom front faces the common and the service lane approaches from
## the west without crossing either the common or water.
static func _reserve_strand_landmark(out: VillagePlan, spec: VillageSpec, common: Rect2,
		site: Rect2) -> void:
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
	var width: float = clampf(sqrt(area * 1.1), 10.0, common.size.x + 8.0)
	var bottom: float = common.position.y - LANDMARK_GAP
	var avail: float = bottom - (site.position.y + 4.0)
	var height: float = clampf(area / width, 8.0, maxf(avail, 8.0))
	var top: float = bottom - height
	if top < site.position.y + 4.0:
		top = site.position.y + 4.0
		height = bottom - top
	var rect := Rect2(Vector2(common.get_center().x - width * 0.5, top),
		Vector2(width, height))
	var front := PackedVector2Array([
		Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y)])
	out.landmark_site = {"poly": Poly.from_rect(rect), "kind": kind, "front": front}

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
## A perpendicular stub off the through road at vertex `i`, running `sign`
## (+1 north, -1 south) for at most `length` metres.
##
## `to_edge` runs it right out to the site boundary instead of stopping three
## metres short. That is not cosmetic: §9.2 exempts a road endpoint ON the
## boundary from the dead-end rule, so a back lane that reaches the fields is
## a way out of the village and a lane that stops short of them is a
## seventy-metre cul-de-sac the road check rightly refuses.
static func _stub(points: PackedVector2Array, i: int, sign: float, length: float,
		site: Rect2, to_edge := false) -> PackedVector2Array:
	var start: Vector2 = points[i]
	var a: int = maxi(0, i - 1)
	var b: int = mini(points.size() - 1, i + 1)
	var tangent: Vector2 = (points[b] - points[a]).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	if signf(normal.y) != signf(sign):
		normal = -normal
	var inset: float = 0.0 if to_edge else 3.0
	var room: float = (start.y - (site.position.y + inset)) if sign < 0.0 		else ((site.end.y - inset) - start.y)
	var reach: float = minf(length, room / maxf(absf(normal.y), 0.2))
	if reach < LANE_MIN_LENGTH:
		return PackedVector2Array()
	return PackedVector2Array([start, start + normal * reach])


## The road vertex nearest `x` but on the far side of it: `side` -1 wants one
## at or west of `x`, +1 one at or east. -1 when the road never gets there.
## Never the polyline's own endpoints, which are the gates.
static func _vertex_outside_x(points: PackedVector2Array, x: float, side: float) -> int:
	var best := -1
	var best_d := INF
	for i in range(1, maxi(1, points.size() - 1)):
		# how far past `x` this vertex is, ON the wanted side: positive when
		# it is on that side, and smallest for the nearest one
		var d: float = (points[i].x - x) * side
		if d < -0.001 or d >= best_d:
			continue
		best_d = d
		best = i
	return best


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


## Two roads touch when a vertex of one lies on the other: a lane's foot is
## a vertex of the road it leaves, or a point along one of its segments.
static func _roads_touch(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for p in a:
		if _on_polyline(p, b):
			return true
	for q in b:
		if _on_polyline(q, a):
			return true
	return false


static func _on_polyline(p: Vector2, pts: PackedVector2Array) -> bool:
	for i in range(pts.size() - 1):
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])) <= JUNCTION_EPS:
			return true
	return pts.size() == 1 and p.distance_to(pts[0]) <= JUNCTION_EPS


static func _find(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i
