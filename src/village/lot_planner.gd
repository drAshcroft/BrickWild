class_name VillageLotPlanner
extends RefCounted
## The second planner: frontages. VILLAGES §5 ("Lots") and §6.
##
## The site planner (VIL-003) has already laid the roads, the common and the
## landmark slot. This file walks every road edge and cuts lots along it, one
## per building the programmer (VIL-005) earned, and puts the building on it.
##
## Three rules govern everything here and are worth stating before the code:
##
## 1. A lot's `front` edge lies ON a road edge -- the line the carriageway's
##    verge ends at, `width / 2 + verge` from the centreline. That is what
##    makes "setback" a measurable number instead of an opinion, and it is
##    why lots are cut per straight SEGMENT of a road polyline: a segment's
##    offset is a straight line, so the front edge is exactly collinear with
##    it and the lot is a simple quadrilateral by construction.
## 2. The lot is sized from the MEASURED `BigGlade.placement()` of the
##    building assigned to it -- every request is sent through
##    `BigGlade.generate()` first -- never from the requested envelope, for
##    the same reason the massing check reads `mass_log` and not the spec.
##    `footprint` (the walls' outline) sizes the lot and the setback;
##    `bounds` (eaves, porches, chimneys) is what the fire gap clears.
## 3. Nothing is cut into a road ribbon, the common, the water or the
##    landmark slot, and no two lots overlap. The single exception is the
##    landmark's OWN lot, which is the reserved slot: reserving ground for
##    the church and then forbidding the church to stand on it would be a
##    contradiction, so `lot["landmark"] == true` marks that one lot and
##    every check spares it (and only it).
##
## Everything is a pure function of the spec: no random draw is made here at
## all, the order buildings are placed in is the programmer's order refined
## by a fixed priority, and the spec is never written to.

## §5's lot table, per lot class. `setback` is door-side face to road edge,
## and the planner uses `use` -- a value inside the documented band with room
## either side for the fit checks to breathe. `fire` is the clear metres
## between two buildings' `bounds`.
const LOT_RULES := {
	&"cottage":   {"set_min": 1.5, "set_max": 6.0,  "use": 3.0,  "fire": 1.5, "depth_k": 1.5, "yard": 2.0},
	&"townhouse": {"set_min": 0.0, "set_max": 1.0,  "use": 0.6,  "fire": 1.0, "depth_k": 1.5, "yard": 1.5},
	&"shop":      {"set_min": 0.0, "set_max": 1.0,  "use": 0.6,  "fire": 1.0, "depth_k": 1.5, "yard": 1.5},
	&"farm":      {"set_min": 4.0, "set_max": 12.0, "use": 7.0,  "fire": 6.0, "depth_k": 4.0, "yard": 6.0},
	&"church":    {"set_min": 6.0, "set_max": 15.0, "use": 8.0,  "fire": 3.0, "depth_k": 4.0, "yard": 2.0},
	&"manor":     {"set_min": 20.0, "set_max": 40.0, "use": 22.0, "fire": 15.0, "depth_k": 4.0, "yard": 4.0},
}

## A terrace -- townhouses allowed to touch -- is §5's one exception to the
## fire gap, and it is only offered to a rich, planted village. Neither
## `street` nor `green` is planted, so in everything this planner can
## currently be handed the answer is "no", by rule and not by accident.
const TERRACE_MIN_WEALTH := 0.5
const TERRACE_FORM := &"planted"

## Which road outranks which, for the corner rule (§5, "corner lots front the
## more important road"). Lower is more important.
const ROAD_RANK := {&"through": 0, &"street": 1, &"lane": 2, &"track": 3, &"path": 4}
## A lot this close to a junction is a corner lot and must front the most
## important road meeting there.
const CORNER_RADIUS := 10.0

const LANE_HALF := 1.25 + 0.5   ## a lane's carriageway half-width plus its verge
const SMITHY_CLEAR := 12.0      ## the smithy from the church and the tavern (VILLAGES 6)
const SITE_MARGIN := 2.0        ## no lot within this of the site edge
const AREA_EPS := 0.05          ## m^2 of overlap that counts as an overlap
const COLLINEAR_EPS := 0.1      ## §5's "on the road edge", in metres
const STEP := 1.0               ## how far a rejected frontage slides before retrying
const MAX_SLIDES := 90


## Site plan + lots + buildings, from the spec alone. The whole of VIL-004.
## Returns a fresh plan; `spec` is not modified.
static func plan(spec: VillageSpec) -> VillagePlan:
	var requests: Array[BuildingRequest] = VillageProgrammer.programme(spec)
	var out: VillagePlan = VillageSitePlanner.plan(spec)
	if out.roads.is_empty():
		return out
	# every request is generated and measured ONCE; the retries below only
	# redo the geometry
	var jobs: Array[Dictionary] = measure_all(requests)
	# every household gets a lot (VIL-006 "housed"): when the form's own
	# roads run out of frontage, the site planner is asked for more lanes,
	# two at a time, until nothing is left unplaced or the site is full
	var unplaced: int = cut_measured(out, jobs)
	for attempt in RETRIES:
		if unplaced <= 0:
			break
		var again: VillagePlan = VillageSitePlanner.plan(spec, int(attempt[0]), float(attempt[1]))
		var left: int = cut_measured(again, jobs)
		if left < unplaced:
			out = again
			unplaced = left
	_trim_lanes(out)
	return out


## What the planner tries, in order, when the form's own frontage will not
## house everyone: more back lanes first, then more ground with more lanes.
## Farms with their six-metre fire gaps and seven-metre setbacks are what
## push a small village up this list.
##
## Two changes here are the whole of the density fix (VIL-012), and both are
## about buying FRONTAGE rather than ground -- §9.1's `density` rule is built
## area over site area, at least 0.05, and four villages in twenty-four were
## failing it because a farm that would not fit grew the ground twice over.
##
##   * every lane is tried before a single metre of ground is added: a lane
##     is frontage on ground the village already has.
##   * the scales run further, because the site now stretches ALONG the road
##     rather than squaring up (see VillageSitePlanner.plan). A stretch of
##     2.0 is twice the area and twice the through-road frontage; squaring up
##     by 1.45 is the same area and only 1.45 times the frontage.
const RETRIES := [[2, 1.0], [4, 1.0], [6, 1.0], [8, 1.0], [10, 1.0], [12, 1.0],
	[8, 1.3], [10, 1.3], [12, 1.3], [10, 1.6], [12, 1.6], [12, 2.0],
	[12, 2.5], [12, 3.0], [12, 3.5]]


const MAX_EXTRA_LANES := 12


## A lane goes somewhere (VILLAGES 9.2): after the lots are cut, every lane
## that dead-ends is cut back to its last lot, and one with no lot at all is
## taken up. The service lanes of the landmark and the manor are theirs.
static func _trim_lanes(plan: VillagePlan) -> void:
	var r: int = plan.roads.size() - 1
	while r >= 0:
		var road: Dictionary = plan.roads[r]
		if road["class"] != &"lane":
			r -= 1
			continue
		var pts: PackedVector2Array = road["points"]
		if pts.size() != 2:
			r -= 1
			continue
		var reserved := false
		for lot in plan.lots:
			if int(lot["road"]) == r and (bool(lot["landmark"]) or lot["class"] == &"manor"):
				reserved = true
		if reserved:
			r -= 1
			continue
		# the far end on another road -- or out on the site boundary, which is
		# the way to the fields -- is not a dead end, and must not be trimmed
		# back into one (VILLAGES 9.2)
		var far: Vector2 = pts[1]
		var joined: bool = VillageMeasure.on_boundary(plan.site, far)
		for j in range(plan.roads.size()):
			if j != r and VillageSitePlanner._on_polyline(far, plan.roads[j]["points"]):
				joined = true
		if joined:
			r -= 1
			continue
		var dir: Vector2 = (pts[1] - pts[0]).normalized()
		var reach := 0.0
		var any := false
		for lot in plan.lots:
			if int(lot["road"]) != r:
				continue
			any = true
			for p in lot["poly"]:
				reach = maxf(reach, (Vector2(p) - pts[0]).dot(dir))
		if not any:
			_drop_road(plan, r)
		else:
			var length: float = clampf(reach + 0.5, VillageSitePlanner.LANE_MIN_LENGTH,
				pts[0].distance_to(pts[1]))
			road["points"] = PackedVector2Array([pts[0], pts[0] + dir * length])
		r -= 1


static func _drop_road(plan: VillagePlan, r: int) -> void:
	plan.roads.remove_at(r)
	for lot in plan.lots:
		if int(lot["road"]) > r:
			lot["road"] = int(lot["road"]) - 1
	for g in plan.gate_crossings:
		if int(g["road"]) > r:
			g["road"] = int(g["road"]) - 1


## Cut lots into an already-sited `plan` for `requests`, generating and
## measuring every one of them. Mutates `plan` (lots, buildings, and the
## service lanes the landmark and the manor need); returns the number of
## requests that found no frontage.
static func cut(plan: VillagePlan, requests: Array[BuildingRequest]) -> int:
	if plan == null or plan.roads.is_empty():
		return requests.size()
	var jobs: Array[Dictionary] = measure_all(requests)
	return cut_measured(plan, jobs) + (requests.size() - jobs.size())


## Generate and measure every request, in order, dropping the ones that do
## not generate. The jobs carry everything the cutting needs and nothing is
## written to them, so one set serves every retry.
static func measure_all(requests: Array[BuildingRequest]) -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	for i in range(requests.size()):
		var job: Dictionary = measure(requests[i])
		if job.is_empty():
			continue
		job["order"] = i
		job["class"] = lot_class(requests[i])
		jobs.append(job)
	return jobs


## Cut lots for already-measured jobs. Returns the number left unplaced.
static func cut_measured(plan: VillagePlan, measured: Array[Dictionary]) -> int:
	if plan == null or plan.roads.is_empty():
		return measured.size()
	var jobs: Array[Dictionary] = measured.duplicate()
	for job in jobs:
		job["siting"] = siting_of(job["request"], job["class"])
	# The arrangement order (VILLAGES §6): the landmark and the lord first
	# because they take their own lanes; then the trades that INSIST on where
	# they stand -- the smithy on the through road at the downwind edge, the
	# tavern on it by a gate -- while that road is still empty; then the rest
	# of the trades; then every household, biggest first.
	jobs.sort_custom(func(a, b) -> bool:
		var pa: int = _order_of(a)
		var pb: int = _order_of(b)
		if pa != pb:
			return pa < pb
		if pa == _ORDER_HOUSE:
			var aa: float = _floor_area(a)
			var ab: float = _floor_area(b)
			if absf(aa - ab) > 0.01:
				return aa > ab
		return int(a["order"]) < int(b["order"]))

	var ctx: Dictionary = _context(plan)
	var placed: int = 0
	var landmark_lane: int = -1
	var manor_lane: int = -1
	# The wealth gradient (VILLAGES §6), enforced rather than hoped for: the
	# households are handed over biggest first, and no house may stand nearer
	# the common than a bigger one already does, less `GRADIENT_SLACK`. The
	# slack is what keeps the rule from emptying a street -- a house that must
	# be a few metres inside its predecessor still reads as the same rank --
	# and without the rule at all the correlation came out at -0.24, because a
	# big house that would not fit near the common let every smaller one past.
	var gradient_floor := 0.0
	for job in jobs:
		var cls: StringName = job["class"]
		if cls == &"church" and plan.landmark_reserved():
			if landmark_lane < 0:
				landmark_lane = _add_landmark_lane(plan)
				ctx = _context(plan)
			if landmark_lane >= 0 and _place_landmark(plan, ctx, job, landmark_lane):
				placed += 1
				continue
		elif cls == &"manor":
			if manor_lane < 0:
				manor_lane = _add_manor_lane(plan, job)
				ctx = _context(plan)
			if manor_lane >= 0 and _place_on_road(plan, ctx, job, [manor_lane], 0.0) >= 0.0:
				placed += 1
				continue
		var floor_for: float = gradient_floor if _order_of(job) == _ORDER_HOUSE else 0.0
		var got: float = _place_on_road(plan, ctx, job,
			_open_roads(plan, [landmark_lane, manor_lane]), floor_for)
		if got >= 0.0:
			placed += 1
			if _order_of(job) == _ORDER_HOUSE:
				gradient_floor = maxf(gradient_floor, got)
	return jobs.size() - placed


## Placing order. Kept as its own function because three things read it: the
## sort, the gradient rule (which applies to households and nothing else) and
## the retry accounting.
const _ORDER_LANDMARK := 0
const _ORDER_LORD := 1
const _ORDER_SITED_TRADE := 2   ## the smithy and the tavern: §6 says WHERE
const _ORDER_TRADE := 3
const _ORDER_HOUSE := 4
## Farms last: they want the edge, and taking their frontage after the
## households have taken theirs is what keeps them out of the middle.
const _ORDER_FARM := 5

## How far inside an already-placed bigger house a smaller one may stand.
const GRADIENT_SLACK := 6.0


static func _order_of(job: Dictionary) -> int:
	var cls: StringName = job["class"]
	match cls:
		&"church":
			return _ORDER_LANDMARK
		&"manor":
			return _ORDER_LORD
		&"farm":
			return _ORDER_FARM
		&"shop":
			return _ORDER_SITED_TRADE if bool(job["siting"].get("insists", false)) \
				else _ORDER_TRADE
	return _ORDER_HOUSE


static func _floor_area(job: Dictionary) -> float:
	var fp: Rect2 = job["footprint"]
	return fp.size.x * fp.size.y


## Everything the legality checks need that depends only on the ROADS: the
## edge runs, the ribbons nothing may stand in, and the junctions the corner
## rule reads. Rebuilt whenever a service lane is added, and never inside the
## slide loop -- recomputing every ribbon per candidate frontage is what made
## the first version of this planner take sixteen seconds a village.
static func _context(plan: VillagePlan) -> Dictionary:
	var ribbons: Array[PackedVector2Array] = []
	for road in plan.roads:
		ribbons.append(VillageSitePlanner.road_ribbon(road, true))
	var carriageways: Array[PackedVector2Array] = []
	for road in plan.roads:
		carriageways.append(VillageSitePlanner.road_ribbon(road, false))
	return {
		"edges": road_edges(plan),
		"ribbons": ribbons,
		"carriageways": carriageways,
		"junctions": VillageSitePlanner.junctions(plan),
	}


## Generate `request` through the library and measure what came back: the
## walls' `footprint`, the full `bounds`, and the placement dictionary the
## plan carries. Empty when the request does not generate.
static func measure(request: BuildingRequest) -> Dictionary:
	var building: GeneratedBuilding = BigGlade.generate(request)
	if building == null or not building.is_ok():
		return {}
	var pl: Dictionary = BigGlade.placement(building)
	if pl.is_empty():
		return {}
	var fp: Rect2 = pl["footprint"]
	var bounds: AABB = pl["bounds"]
	var brect := Rect2(Vector2(bounds.position.x, bounds.position.z),
		Vector2(bounds.size.x, bounds.size.z))
	# The lot is sized from the UNION of the two measured rects, about the
	# point the building is anchored by: the middle of the footprint's front
	# edge, which is where its door is and where the setback is measured
	# from. `over` is how far the eaves reach out in FRONT of that edge --
	# without it a lot sized on the walls alone would hang its own roof over
	# the road.
	var u: Rect2 = fp.merge(brect)
	var anchor := Vector2(fp.position.x + fp.size.x * 0.5, fp.position.y)
	return {
		"request": request,
		"placement": pl,
		"footprint": fp,
		"bounds_rect": brect,
		"half_w": maxf(anchor.x - u.position.x, u.end.x - anchor.x),
		"over": maxf(0.0, anchor.y - u.position.y),
		"back": maxf(0.0, u.end.y - anchor.y),
		"width": u.size.x,
		"depth": u.size.y,
	}


## §5's lot classes, from the request the programmer made. A farmer's house
## is a farm (a yard, a big fire gap, out on a lane); a `townhouse`-styled
## house and every shop are town lots; everything else domestic is a cottage.
static func lot_class(request: BuildingRequest) -> StringName:
	match request.kind:
		&"church", &"temple":
			return &"church"
		&"castle":
			return &"manor"
		&"shop":
			return &"shop"
		&"house":
			if request.purpose == &"farmer":
				return &"farm"
			if request.style == &"townhouse":
				return &"townhouse"
	return &"cottage"


## True when this village is allowed to build a terrace (§5): rich, planted,
## and only for town lots. Public so the check in the suite asks the rule
## rather than re-deriving it.
static func terraces_allowed(spec: VillageSpec) -> bool:
	return spec != null and spec.wealth >= TERRACE_MIN_WEALTH and spec.form == TERRACE_FORM


static func fire_gap(cls: StringName, spec: VillageSpec) -> float:
	var gap: float = float(LOT_RULES.get(cls, LOT_RULES[&"cottage"])["fire"])
	if cls in [&"townhouse", &"shop"] and terraces_allowed(spec):
		return 0.0
	return gap


# ------------------------------------------------------------- the road edges

## Every straight run of road edge in the plan, as {"road", "seg", "side",
## "a", "b", "dir", "normal", "length"}: `a`->`b` is the edge line (the
## carriageway offset by half its width plus its verge) and `normal` points
## AWAY from the road, into the land a lot would take. This is the one place
## "a road edge" is defined, and both the planner and its checks use it.
static func road_edges(plan: VillagePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var pts: PackedVector2Array = road["points"]
		var half: float = float(road["width"]) * 0.5 + float(road["verge"])
		for s in range(pts.size() - 1):
			var a: Vector2 = pts[s]
			var b: Vector2 = pts[s + 1]
			var d: Vector2 = b - a
			if d.length() < 1e-6:
				continue
			d = d.normalized()
			for side_v in [1.0, -1.0]:
				var side: float = side_v
				var n: Vector2 = Vector2(-d.y, d.x) * side
				out.append({
					"road": r, "seg": s, "side": side,
					"a": a + n * half, "b": b + n * half,
					"dir": d * side, "normal": n,
					"length": a.distance_to(b),
				})
	return out


## Distance from `p` to the infinite line through the edge `e`. `<= 0.1` is
## §5's "the front edge is on the road edge".
static func distance_to_edge_line(e: Dictionary, p: Vector2) -> float:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var d: Vector2 = (b - a)
	if d.length() < 1e-9:
		return a.distance_to(p)
	return absf(d.normalized().cross(p - a))


# --------------------------------------------------------------- lot cutting

static func _open_roads(plan: VillagePlan, reserved: Array) -> Array:
	## Every road an ordinary building may front: the service lanes cut for
	## the landmark and the manor are theirs alone (§6, "on its own lane").
	var out: Array = []
	for r in range(plan.roads.size()):
		if r in reserved:
			continue
		out.append(r)
	out.sort_custom(func(a, b) -> bool:
		return int(ROAD_RANK.get(plan.roads[a]["class"], 9)) < int(ROAD_RANK.get(plan.roads[b]["class"], 9)))
	return out


## VILLAGES §6, as a table: where each thing goes, so the arrangement is one
## readable rule per row instead of a special case buried in the placer.
##
##   road      the road class it insists on; empty means any road will do
##   insists   true for the trades §6 gives a PLACE, not just a road -- they
##             are placed before the households, while that road is empty
##   toward    what the candidate frontages are sorted by:
##               &"common"  nearest the common's centre first (the default:
##                          the village fills from the middle outward)
##               &"gate"    nearest a gate first
##               &"edge"    furthest from the common first
##               &"outside" nearest the SITE BOUNDARY first, which is not the
##                          same thing at all once the site stretches along
##                          its road: the far end of the through road is a
##                          long way from the common and still dead centre
##                          between the north and south edges, which is
##                          exactly where §9.4 says a farm may not stand
##   side      &"east" or &"west": only frontages that side of the common,
##             unless there are none at all. The smithy is downwind (+x by
##             convention) for the fire, the noise and the smell; the tavern
##             is upwind of it, at the other gate, for the same reason -- and
##             because the two chasing the same end of the through road is
##             what made the smithy's twelve-metre clearance from the tavern
##             fail on a small site.
##
## A row's `road` is a preference, not a wall: a thing that cannot find any
## frontage on the road it wants falls back to the rest, because a village
## with an unhoused smithy is worse than one with a smithy on a lane.
## A farm goes to the edge and is NOT part of the wealth gradient. The two
## rules would otherwise contradict each other -- §9.4's `gradient` wants the
## big houses in the middle and a farmhouse is a big house -- so each names
## the set it measures: `gradient` judges the houses free to stand round the
## common, `farms outside` judges the farms. Mixing them put farms forty
## metres inside the edge and still only reached a -0.02 correlation.
const SITING := {
	&"blacksmith": {"road": &"through", "insists": true, "toward": &"edge", "side": &"east"},
	&"tavern": {"road": &"through", "insists": true, "toward": &"gate", "side": &"west"},
	&"inn": {"road": &"through", "toward": &"gate"},
	&"farm": {"road": &"track", "toward": &"outside"},
}
const SITING_DEFAULT := {"toward": &"common"}


## The siting rule for one request. Shops answer to their business; everything
## else to its lot class.
static func siting_of(request: BuildingRequest, cls: StringName) -> Dictionary:
	if request != null and request.kind == &"shop" and SITING.has(request.purpose):
		return SITING[request.purpose]
	return SITING.get(cls, SITING_DEFAULT)


## Place one job. Returns its distance from the common's centre when it was
## placed and -1 when it was not -- the distance, rather than a bool, because
## the wealth gradient is enforced by feeding it back in as the next house's
## `floor` (see cut_measured).
static func _place_on_road(plan: VillagePlan, ctx: Dictionary, job: Dictionary,
		roads: Array, floor_d := 0.0) -> float:
	var cls: StringName = job["class"]
	var rule: Dictionary = LOT_RULES.get(cls, LOT_RULES[&"cottage"])
	var gap: float = fire_gap(cls, plan.spec)
	var frontage: float = 2.0 * float(job["half_w"]) + maxf(gap, 1.0)
	var setback: float = _setback(rule, job)
	var depth: float = setback + float(job["back"]) + float(rule["yard"])
	var site: Dictionary = job.get("siting", SITING_DEFAULT)
	var cc: Vector2 = plan.site.get_center()
	if not plan.commons.is_empty():
		cc = Poly.bounding_rect(plan.commons[0]["poly"]).get_center()
	var gates: Array[Vector2] = _gates(plan)
	# The road it insists on, alone, first; the rest only if that road has no
	# room at all.
	var want_class: StringName = site.get("road", &"")
	if want_class != &"":
		var preferred: Array = []
		for r0 in roads:
			if plan.roads[r0]["class"] == want_class:
				preferred.append(r0)
		if not preferred.is_empty() and roads.size() > preferred.size():
			var got: float = _place_on_road(plan, ctx, job, preferred, floor_d)
			if got >= 0.0:
				return got
	# Every road at once, sorted by what this job is looking for -- not road
	# by road in rank order taking the first legal spot on each.
	#
	# The difference is the whole arrangement. A farm wants the one frontage
	# nearest the site edge and a house wants the one nearest the common;
	# walking the roads in rank order gave each of them the best spot on the
	# THROUGH ROAD, which is neither. Farms ended up at the inner end of one
	# lane while the outer end of the next stood empty, and houses lined the
	# through road while the street round the common stood empty -- which is
	# what §9.4's `common` rule, sixty per cent of the common's edge fronted,
	# was measuring at fifty.
	var all: Array = []
	for r in roads:
		all.append_array(_spots(ctx, r, cc, gates, plan.site, site))
	for spots in [_sorted(all, site)]:
		# the gradient floor: no household nearer the common than a bigger one
		if floor_d > 0.0:
			var far: Array = []
			for spot in spots:
				if float(spot["d"]) >= floor_d - GRADIENT_SLACK:
					far.append(spot)
			if not far.is_empty():
				spots = far
		for spot in spots:
			var lot: Dictionary = _make_lot(spot["e"], float(spot["m"]), frontage, depth, setback)
			if _lot_is_legal(plan, ctx, lot, job, gap):
				_commit(plan, lot, job, rule)
				return float(spot["d"])
	return -1.0


## Every candidate frontage along road `r`, in the order this job wants to
## try them. `d` is always the distance from the common's centre, whatever
## the sort was, because that is what the gradient rule measures.
static func _spots(ctx: Dictionary, r: int, cc: Vector2, gates: Array[Vector2],
		ground: Rect2, site: Dictionary) -> Array:
	var spots: Array = []
	for e in ctx["edges"]:
		if int(e["road"]) != r:
			continue
		var run: float = float(e["length"])
		var origin: Vector2 = e["a"] if float(e["side"]) > 0.0 else e["b"]
		var m: float = 0.0
		var slides: int = 0
		while m <= run and slides < MAX_SLIDES:
			var mid: Vector2 = origin + (e["dir"] as Vector2) * m
			var to_gate := INF
			for g in gates:
				to_gate = minf(to_gate, mid.distance_to(g))
			spots.append({"e": e, "m": m, "mid": mid, "d": mid.distance_to(cc),
				"gate": to_gate, "edge": _to_edge(ground, mid)})
			m += STEP
			slides += 1
	# which side of the common this trade belongs on: the smithy downwind
	# (+x by convention) for the fire, the noise and the smell; the tavern
	# upwind of it (VILLAGES §6)
	var side: StringName = site.get("side", &"")
	if side != &"":
		var want: float = 1.0 if side == &"east" else -1.0
		var kept: Array = []
		for spot in spots:
			if (float(spot["mid"].x) - cc.x) * want >= 0.0:
				kept.append(spot)
		if not kept.is_empty():
			spots = kept
	return _sorted(spots, site)


## Order a list of candidate frontages the way this siting wants them tried.
## Pulled out of _spots so the same order can be applied across roads.
static func _sorted(spots: Array, site: Dictionary) -> Array:
	match StringName(site.get("toward", &"common")):
		&"gate":
			spots.sort_custom(func(a, b) -> bool: return float(a["gate"]) < float(b["gate"]))
		&"edge":
			spots.sort_custom(func(a, b) -> bool: return float(a["d"]) > float(b["d"]))
		&"outside":
			spots.sort_custom(func(a, b) -> bool: return float(a["edge"]) < float(b["edge"]))
		_:
			spots.sort_custom(func(a, b) -> bool: return float(a["d"]) < float(b["d"]))
	return spots


## How far inside the site a point is: the distance to the nearest edge of
## the ground the village stands on. This is the number §9.4's `farms outside`
## rule measures, so it is the number the planner steers a farm by.
static func _to_edge(ground: Rect2, p: Vector2) -> float:
	return minf(minf(p.x - ground.position.x, ground.end.x - p.x),
		minf(p.y - ground.position.y, ground.end.y - p.y))


## Where the village is entered: its gate crossings, or, with no enclosure,
## the two ends of the through road. The same definition VillageMeasure uses,
## so the planner is steering by the number the check will measure.
static func _gates(plan: VillagePlan) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g in plan.gate_crossings:
		out.append(g["pos"])
	if not out.is_empty():
		return out
	for r in plan.roads_of_class(&"through"):
		var pts: PackedVector2Array = plan.roads[r]["points"]
		if pts.size() >= 2:
			out.append(pts[0])
			out.append(pts[pts.size() - 1])
	return out


## The lot whose front edge is CENTRED `m` metres along the road edge `e`.
##
## The frontage is anchored by its midpoint, not its start, and may overhang
## the segment's ends: the through road is sampled every 10 m, and a
## ten-metre cottage plus its fire gap does not fit inside a ten-metre
## segment, so a start-anchored cut would place nothing at all on the most
## important road in the village. What keeps the overhang honest is that the
## front edge still lies exactly on that segment's own offset line (so §5's
## collinearity holds), its midpoint still stands over the segment, and the
## ribbon test still refuses anything the overhang pushes at the carriageway.
## The setback this lot will use: the class's preferred value, but never so
## small that the measured eaves (`over`) reach past the front edge onto the
## road, and never outside §5's band for the class.
static func _setback(rule: Dictionary, job: Dictionary) -> float:
	return clampf(maxf(float(rule["use"]), float(job["over"]) + 0.2),
		float(rule["set_min"]), float(rule["set_max"]))


static func _make_lot(e: Dictionary, m: float, frontage: float, depth: float,
		setback: float) -> Dictionary:
	var dir: Vector2 = e["dir"]
	var n: Vector2 = e["normal"]
	var origin: Vector2 = e["a"] if float(e["side"]) > 0.0 else e["b"]
	var mid: Vector2 = origin + dir * m
	var a: Vector2 = mid - dir * frontage * 0.5
	var b: Vector2 = mid + dir * frontage * 0.5
	var poly := PackedVector2Array([a, b, b + n * depth, a + n * depth])
	return {
		"poly": poly,
		"front": PackedVector2Array([a, b]),
		"road": int(e["road"]),
		"normal": n,
		"setback": setback,
		"landmark": false,
	}


static func _lot_is_legal(plan: VillagePlan, ctx: Dictionary, lot: Dictionary,
		job: Dictionary, gap: float) -> bool:
	var poly: PackedVector2Array = lot["poly"]
	if not _inside_site(plan.site, poly):
		return false
	for ribbon in ctx["ribbons"]:
		if _overlaps(poly, ribbon):
			return false
	for c in plan.commons:
		if _overlaps(poly, c["poly"]):
			return false
	for w in plan.water:
		if _overlaps(poly, w["poly"]):
			return false
	if not bool(lot["landmark"]) and plan.landmark_reserved():
		if _overlaps(poly, plan.landmark_site["poly"]):
			return false
	for other in plan.lots:
		if _overlaps(poly, other["poly"]):
			return false
	if _corner_blocked(plan, ctx, lot):
		return false
	# the fire gap is between BUILDINGS, not lots: measure the bounds rects.
	var xf: Transform3D = _transform_for(lot, job)
	var mine: PackedVector2Array = Placement.world_rect(job["placement"], xf, false)
	# A townhouse's setback band tops out at 1 m, so its eaves genuinely do
	# reach out past its own front edge and over the verge -- that is what a
	# jettied street front is. What is never allowed is architecture over the
	# CARRIAGEWAY, so the walls are held inside the lot and the eaves are
	# held out of the road itself.
	if not _poly_contains(lot["poly"], Placement.world_rect(job["placement"], xf, true)):
		return false
	for way in ctx["carriageways"]:
		if _overlaps(mine, way):
			return false
	var req: BuildingRequest = job["request"]
	var loud: bool = req.kind == &"shop" and req.purpose == &"blacksmith"
	var quiet: bool = req.kind in [&"church", &"temple"] or (req.kind == &"shop" and req.purpose == &"tavern")
	for b in plan.buildings:
		var theirs: PackedVector2Array = Placement.world_rect(
			b["placement"], b["transform"], false)
		var want: float = maxf(gap, fire_gap(b["class"], plan.spec))
		# fire, noise and the smell: the smithy stands SMITHY_CLEAR from the
		# church and the tavern, whichever of them came first (VILLAGES 6)
		var other: BuildingRequest = b["request"]
		var other_loud: bool = other.kind == &"shop" and other.purpose == &"blacksmith"
		var other_quiet: bool = other.kind in [&"church", &"temple"] \
			or (other.kind == &"shop" and other.purpose == &"tavern")
		if (loud and other_quiet) or (quiet and other_loud):
			want = maxf(want, SMITHY_CLEAR)
		if _poly_distance(mine, theirs) < want - 1e-3:
			return false
	return true


## §5: a corner lot fronts the more important road. A candidate on a lesser
## road that reaches into a junction's corner is refused, which leaves the
## corner for the road that outranks it -- and since roads are walked in rank
## order, the important one has already taken it.
static func _corner_blocked(plan: VillagePlan, ctx: Dictionary, lot: Dictionary) -> bool:
	var mine: int = int(ROAD_RANK.get(plan.roads[int(lot["road"])]["class"], 9))
	for j in ctx["junctions"]:
		var pos: Vector2 = j["pos"]
		if _point_to_poly(pos, lot["poly"]) > CORNER_RADIUS:
			continue
		for r in j["roads"]:
			if int(ROAD_RANK.get(plan.roads[int(r)]["class"], 9)) < mine:
				return true
	return false


## The transform that puts the building on the lot: rotated so its local -Z
## points at the front edge, and translated so the front face of the measured
## footprint stands `setback` metres back from that edge, centred on it.
static func _transform_for(lot: Dictionary, job: Dictionary) -> Transform3D:
	var n: Vector2 = lot["normal"]
	var setback: float = float(lot["setback"])
	var yaw: float = atan2(n.x, n.y)
	var basis := Basis(Vector3.UP, yaw)
	var front: PackedVector2Array = lot["front"]
	var mid: Vector2 = (front[0] + front[1]) * 0.5
	var target: Vector2 = mid + n * setback
	var fp: Rect2 = job["footprint"]
	var local := Vector3(fp.position.x + fp.size.x * 0.5, 0.0, fp.position.y)
	var origin: Vector3 = Vector3(target.x, 0.0, target.y) - basis * local
	return Transform3D(basis, origin)


static func _commit(plan: VillagePlan, lot: Dictionary, job: Dictionary, _rule: Dictionary) -> void:
	var xf: Transform3D = _transform_for(lot, job)
	var record := {
		"poly": lot["poly"],
		"front": lot["front"],
		"road": int(lot["road"]),
		"setback": float(lot["setback"]),
		"landmark": bool(lot["landmark"]),
		"class": job["class"],
	}
	plan.lots.append(record)
	var door: Vector3 = job["placement"]["door"]
	plan.buildings.append({
		"lot": plan.lots.size() - 1,
		"request": job["request"],
		"placement": job["placement"],
		"transform": xf,
		"door": xf * door,
		"kind": job["request"].kind,
		"class": job["class"],
	})


# ------------------------------------------------- the landmark's own frontage

## §6: the church stands on the slot the site planner reserved before any lot
## existed, and §5 wants its front edge on a road. A short lane is run up the
## west side of the slot for exactly that. Returns the road index, or -1.
static func _add_landmark_lane(plan: VillagePlan) -> int:
	var rect: Rect2 = Poly.bounding_rect(plan.landmark_site["poly"])
	var setback: float = float(LOT_RULES[&"church"]["use"])
	var lane_x: float = rect.position.x - setback - LANE_HALF
	if lane_x - LANE_HALF < plan.site.position.x + SITE_MARGIN:
		return -1
	var through: PackedVector2Array = plan.roads[0]["points"]
	var start_y: float = _polyline_y_at_x(through, lane_x)
	var end_y: float = rect.end.y + 2.0
	if end_y - start_y < 8.0:
		return -1
	var pts := PackedVector2Array([Vector2(lane_x, start_y), Vector2(lane_x, end_y)])
	var lane: Dictionary = _lane(pts, plan.spec.wealth)
	# the lane itself must not be laid across the common, the water or the
	# slot it serves.
	var ribbon: PackedVector2Array = VillageSitePlanner.road_ribbon(lane, true)
	for c in plan.commons:
		if _overlaps(ribbon, c["poly"]):
			return -1
	for w in plan.water:
		if _overlaps(ribbon, w["poly"]):
			return -1
	if _overlaps(ribbon, plan.landmark_site["poly"]):
		return -1
	plan.roads.append(lane)
	return plan.roads.size() - 1


static func _place_landmark(plan: VillagePlan, ctx: Dictionary, job: Dictionary, road: int) -> bool:
	var rect: Rect2 = Poly.bounding_rect(plan.landmark_site["poly"])
	var gap: float = fire_gap(&"church", plan.spec)
	var rule: Dictionary = LOT_RULES[&"church"]
	var setback: float = _setback(rule, job)
	var frontage: float = maxf(rect.size.y, 2.0 * float(job["half_w"]) + maxf(gap, 1.0))
	var depth: float = setback + maxf(float(job["back"]), rect.size.x) + float(rule["yard"])
	for e in ctx["edges"]:
		if int(e["road"]) != road:
			continue
		# the lane runs north past the slot's west side, so the edge that
		# fronts the slot is the one whose normal points east.
		var n: Vector2 = e["normal"]
		if n.x <= 0.0:
			continue
		var run: float = float(e["length"])
		var origin: Vector2 = e["a"] if float(e["side"]) > 0.0 else e["b"]
		var dir: Vector2 = e["dir"]
		var want_t: float = 0.0
		if absf(dir.y) > 1e-6:
			want_t = (rect.position.y - 1.0 - origin.y) / dir.y
		var t: float = clampf(want_t + frontage * 0.5, 0.0, run)
		var lot: Dictionary = _make_lot(e, t, frontage, depth, setback)
		lot["landmark"] = true
		if _lot_is_legal(plan, ctx, lot, job, gap):
			_commit(plan, lot, job, rule)
			return true
	return false


## §6: the manor is at the head of the village, at the far end of its own
## lane. The lane runs north off the through road near the site's east edge.
static func _add_manor_lane(plan: VillagePlan, job: Dictionary) -> int:
	var setback: float = float(LOT_RULES[&"manor"]["use"])
	var need: float = setback + float(job["back"]) + float(LOT_RULES[&"manor"]["yard"])
	var lane_x: float = plan.site.end.x - SITE_MARGIN - LANE_HALF - need - 1.0
	var through: PackedVector2Array = plan.roads[0]["points"]
	var start_y: float = _polyline_y_at_x(through, lane_x)
	# right up to the site's edge: the manor's frontage is its own width plus
	# a fifteen-metre fire gap, which is longer than any lane laid for a
	# handful of cottages.
	var end_y: float = plan.site.end.y - SITE_MARGIN
	if end_y - start_y < float(job["width"]) * 0.5 + 12.0:
		return -1
	var lane: Dictionary = _lane(PackedVector2Array([Vector2(lane_x, start_y), Vector2(lane_x, end_y)]),
		plan.spec.wealth)
	var ribbon: PackedVector2Array = VillageSitePlanner.road_ribbon(lane, true)
	for c in plan.commons:
		if _overlaps(ribbon, c["poly"]):
			return -1
	if plan.landmark_reserved() and _overlaps(ribbon, plan.landmark_site["poly"]):
		return -1
	for w in plan.water:
		if _overlaps(ribbon, w["poly"]):
			return -1
	for lot in plan.lots:
		if _overlaps(ribbon, lot["poly"]):
			return -1
	plan.roads.append(lane)
	return plan.roads.size() - 1


static func _lane(points: PackedVector2Array, wealth: float) -> Dictionary:
	var row: Dictionary = VillageSitePlanner.ROAD_CLASSES[&"lane"]
	var band: int = 0 if wealth < 0.34 else (1 if wealth < 0.67 else 2)
	return {
		"points": points,
		"class": &"lane",
		"width": float(row["width"]),
		"verge": float(row["verge"]),
		"surface": String(row["surface"][band]),
	}


static func _polyline_y_at_x(points: PackedVector2Array, x: float) -> float:
	var best: float = points[0].y
	var best_d: float = INF
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		if absf(b.x - a.x) > 1e-6 and x >= minf(a.x, b.x) and x <= maxf(a.x, b.x):
			var t: float = (x - a.x) / (b.x - a.x)
			return a.y + (b.y - a.y) * t
		for p in [a, b]:
			var d: float = absf(p.x - x)
			if d < best_d:
				best_d = d
				best = p.y
	return best


# ------------------------------------------------------------------ geometry

## Overlap area > `AREA_EPS`. Uses `Geometry2D`, not `Poly.intersection_area`,
## because road ribbons and (later) water are concave and the convex clip
## would quietly answer about their hulls.
static func _overlaps(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return overlap_area(a, b) > AREA_EPS


static func overlap_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if a.size() < 3 or b.size() < 3:
		return 0.0
	var total := 0.0
	for piece in Geometry2D.intersect_polygons(a, b):
		total += Poly.area(piece)
	return total


## True when every part of `inner` lies within `outer`.
static func _poly_contains(outer: PackedVector2Array, inner: PackedVector2Array) -> bool:
	return overlap_area(outer, inner) >= Poly.area(inner) - AREA_EPS


static func _inside_site(site: Rect2, poly: PackedVector2Array) -> bool:
	var inner := Rect2(site.position + Vector2(SITE_MARGIN, SITE_MARGIN),
		site.size - Vector2(SITE_MARGIN, SITE_MARGIN) * 2.0)
	for p in poly:
		if not inner.has_point(p):
			return false
	return true


## Least distance between two polygons; 0 when they touch or overlap.
static func _poly_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if overlap_area(a, b) > 0.0:
		return 0.0
	var best := INF
	for i in range(a.size()):
		var a1: Vector2 = a[i]
		var a2: Vector2 = a[(i + 1) % a.size()]
		for j in range(b.size()):
			var b1: Vector2 = b[j]
			var b2: Vector2 = b[(j + 1) % b.size()]
			var pair: PackedVector2Array = Geometry2D.get_closest_points_between_segments(a1, a2, b1, b2)
			best = minf(best, pair[0].distance_to(pair[1]))
	return best


static func _point_to_poly(p: Vector2, poly: PackedVector2Array) -> float:
	if Poly.contains_point(poly, p):
		return 0.0
	var best := INF
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best
