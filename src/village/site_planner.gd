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
static func plan(spec: VillageSpec, extra_lanes := 0, site_scale := 1.0) -> VillagePlan:
	var out := VillagePlan.new(spec)
	if spec == null or not spec.valid():
		push_error("VillageSitePlanner: invalid spec")
		return out
	if spec.form == &"":
		push_error("VillageSitePlanner: spec.generate() has not been called")
		return out
	out.site = site_rect(spec)
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
	# 3. more frontage when the lot planner asks for it (VIL-006): back lanes
	# off the through road, on the side away from the common first, at the
	# spots the form did not take
	_extra_lanes(out, spec, through, extra_lanes)
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


## A street up one side of the common, across its far side and back down the
## other, closed at both ends by the through road itself -- so the graph is
## one component with no dead end, and every side of the common has a road a
## lot can front. Returns the y of the far side, or -INF when the site has no
## room for it and the common keeps its single frontage.
static func _ring_street(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		common: Rect2, site: Rect2) -> float:
	var clear: float = _ring_half() + COMMON_ROAD_GAP
	var far_y: float = common.end.y + clear
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
	# The legs must stand OUTSIDE the common, not merely near it: the through
	# road is sampled every ten metres and bends, so the nearest vertex to a
	# wanted x can be five metres the wrong side of it -- which laid the lane
	# through the green on seven of fifty street seeds.
	var ia: int = _vertex_outside_x(through, common.position.x - clear, -1.0)
	var ib: int = _vertex_outside_x(through, common.end.x + clear, 1.0)
	if ia < 0 or ib < 0 or ib - ia < 1:
		return -INF
	var west := Vector2(through[ia].x, far_y)
	var east := Vector2(through[ib].x, far_y)
	if west.x < site.position.x + SITE_MARGIN_M or east.x > site.end.x - SITE_MARGIN_M:
		return -INF
	out.roads.append(_road(PackedVector2Array([through[ia], west]), &"street", spec.wealth))
	out.roads.append(_road(PackedVector2Array([west, east]), &"street", spec.wealth))
	out.roads.append(_road(PackedVector2Array([east, through[ib]]), &"street", spec.wealth))
	return far_y


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
