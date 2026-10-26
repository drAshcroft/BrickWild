class_name VillageWaterForm
extends RefCounted
## `water`: a village standing IN its shallows (VTER-FORM-WATER,
## docs/VILLAGE_TERRAIN.md "The water form"). Ganvié on Lake Nokoué (54 % of
## its buildings over the water), Kampong Ayer on the Brunei river (all of
## them), the stilt quarters of every shallow shore: houses on piles, joined by
## boardwalks, reached from a street on the bank.
##
## The ground derives this form at rows 2 and 9 of the form rule (the wider
## ground mostly wet; a fishing village on a lake). It is the shore form
## (VillageShoreForm: the frame on the shoreline, the shore street, the common
## on the bank, the landmark inland) with the shallows built on:
##
##   1. PIERS (`_piers`): boardwalks square off the shore street, every
##      PIER_SPACING metres along it, out over the water as far beyond the
##      shoreline as the households need (`reach`: a row of pile lots each
##      side, LOT_PITCH a house) -- each laid only where the water under it
##      stays within the piles' range (DEEP_MAX), clear of the common and of
##      the street's other junctions. At least two, one per PER_PIER
##      households.
##   2. THE FAR WALK: a boardwalk along the shore at the piers' far ends,
##      joining them, so every boardwalk is a way through and none a dead end.
##   3. A boardwalk is a `path` road carrying `"boardwalk": true` and its deck
##      level `"deck_m"` (the water level plus HousePiles.FREEBOARD_DEFAULT): a
##      footway in every check, and over the water it is a CROSSING of kind
##      `boardwalk` (VillageWaterPlan.crossings), which is what the walk, the
##      road check and the builder (VillageBoardwalk) already read. Its crossing
##      is as wide as the road's verged ribbon, so the lots it fronts meet its
##      deck.
##   4. PILE LOTS: the lot planner offers every household (`place_on_piles`)
##      the boardwalks first, as a house on piles (HousePiles), measured once.
##      A pile lot lies wholly on the water, over a bed no deeper than the
##      piles reach; it records `"piles"`: the deck level, the water's depth,
##      and the house's landing from its door to the boardwalk -- the floor the
##      walk restores over the water. The request is asked for exactly that
##      depth and that landing. What finds no pile lot stands on the bank.
##
## Where the shallows will not take two piers (deep water off the bank, no
## water level), the form is the shore form, and without a shoreline in the
## frame the straight strand, exactly as `shore` is planned. Without terrain
## the form is never derived. Pure: the same spec on the same ground is the
## same plan.

## Boardwalks: a pier every this many metres along the street (two rows of
## pile lots back to back fit between), out this far beyond the shoreline.
const PIER_SPACING := 40.0
## The first pile lot starts this far out from the shoreline (the bank, the
## ramp onto the deck), each house takes LOT_PITCH of a pier's side, and a pier
## is never shorter than REACH_MIN nor longer than REACH_MAX beyond the shore.
const FIRST_M := 12.0
const LOT_PITCH := 12.5
const REACH_MIN := 30.0
const REACH_MAX := 90.0
## Households per pier, for how many piers to lay.
const PER_PIER := 6
const PIERS_MAX := 8
## Water the piles stand in: no deeper than this anywhere a pier or its lots
## will stand (HousePiles.MAX_WATER_M less a margin for the bed's carving).
const DEEP_MAX := HousePiles.MAX_WATER_M - 0.5
## A pile lot's bed is read on this lattice; the carved bed is never above
## the water level less this (VillageGroundSurface._carve, BANK_SHELF).
const BED_STEP := 2.0
const CARVE_M := 0.41
## The site's margin seaward of the far walk.
const FAR_ROW_M := 6.0
## A pier's start keeps this far from every other junction on the street, and
## its ribbon this far clear of the common.
const JUNCTION_CLEAR := 14.0
const COMMON_CLEAR := 6.0
## Piers stay this far inside the site's ends.
const END_CLEAR := 22.0


# ===================================================================== the plan

## The whole site plan of a water village on `ground` (the frame
## VillageShoreForm.site chose). Returns the shore plan, with its boardwalks
## when the shallows take them.
static func plan(spec: VillageSpec, extra_lanes := 0, site_scale := 1.0, minimum_depth := 0.0,
		shore_depth := 0.0, ground: VillageTerrain = null) -> VillagePlan:
	var out: VillagePlan = VillageShoreForm.plan(spec, extra_lanes, site_scale, minimum_depth,
		shore_depth, ground)
	if out.shoreline.is_empty() or out.roads.is_empty() or is_nan(ground.water_level_m):
		return out
	var piers := _piers(out, spec)
	if piers.size() < 2:
		return out
	# the site reaches over the shallows the boardwalks and their lots stand in
	var far_y := -INF
	for p in piers:
		far_y = maxf(far_y, (p[p.size() - 1] as Vector2).y)
	var end_y: float = minf(far_y + FAR_ROW_M + 4.0, out.site.position.y + VillageSitePlanner.SITE_MAX_SIDE)
	if end_y > out.site.end.y:
		out.site = Rect2(out.site.position, Vector2(out.site.size.x, end_y - out.site.position.y))
		# the ground's water re-read over the grown site
		var kept: Array[Dictionary] = []
		for w in out.water:
			if not bool(w.get("ground", false)):
				kept.append(w)
		out.water = kept
		VillageGroundWater.add(out)
	var deck: float = deck_level(ground)
	var far := _far_walk(out, piers)
	for p in piers:
		out.roads.append(_boardwalk(p, spec, deck))
	out.roads.append(_boardwalk(far, spec, deck))
	out.water_crossings = VillageWaterPlan.crossings(out.water, out.roads)
	return out


## The deck level of every boardwalk and pile house on this ground.
static func deck_level(ground: VillageTerrain) -> float:
	return ground.water_level_m + HousePiles.FREEBOARD_DEFAULT


static func _boardwalk(points: PackedVector2Array, spec: VillageSpec, deck: float) -> Dictionary:
	var road: Dictionary = VillageSitePlanner._road(points, &"path", spec.wealth)
	road["surface"] = "boards"
	road["boardwalk"] = true
	road["deck_m"] = deck
	return road


static func is_boardwalk(road: Dictionary) -> bool:
	return bool(road.get("boardwalk", false))


## How many piers the households want, and how far out they run: a row of
## pile lots each side of each pier.
static func piers_for(spec: VillageSpec) -> int:
	return clampi(int(ceil(float(spec.households) / float(PER_PIER))), 2, PIERS_MAX)


static func reach_for(spec: VillageSpec) -> float:
	var per_side: int = int(ceil(float(spec.households) / float(2 * piers_for(spec))))
	return clampf(FIRST_M + LOT_PITCH * float(per_side) + 4.0, REACH_MIN, REACH_MAX)


## The piers, west to east: each [start on the street, its end `reach_for` beyond
## the shoreline], laid on the shoreline's own columns.
static func _piers(out: VillagePlan, spec: VillageSpec) -> Array[PackedVector2Array]:
	var shore: PackedVector2Array = out.shoreline
	var street: PackedVector2Array = out.roads[0]["points"]
	var g: VillageTerrain = out.ground
	var wl: float = g.water_level_m
	var bounds := g.bounds().grow(-2.0)
	var wanted: int = piers_for(spec)
	var reach: float = reach_for(spec)
	var common := Rect2()
	if not out.commons.is_empty():
		common = Poly.bounding_rect(out.commons[0]["poly"])
	var centre_x: float = common.get_center().x if common.has_area() else 0.0
	# the street's other junctions: every other road's ends on it
	var taken: Array[Vector2] = []
	for r in range(1, out.roads.size()):
		var pts: PackedVector2Array = out.roads[r]["points"]
		taken.append(pts[0])
		taken.append(pts[pts.size() - 1])
	var order: Array[int] = []
	for i in range(shore.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := absf(shore[a].x - centre_x)
		var db := absf(shore[b].x - centre_x)
		return da < db if absf(da - db) > 1e-6 else shore[a].x < shore[b].x)
	var chosen: Array[PackedVector2Array] = []
	for i in order:
		if chosen.size() >= wanted:
			break
		var x: float = shore[i].x
		if x < out.site.position.x + END_CLEAR or x > out.site.end.x - END_CLEAR:
			continue
		if common.has_area() and x > common.position.x - COMMON_CLEAR and x < common.end.x + COMMON_CLEAR:
			continue
		var close := false
		for c in chosen:
			close = close or absf(c[0].x - x) < PIER_SPACING - 0.01
		if close:
			continue
		var start := Vector2(x, VillageLotPlanner._polyline_y_at_x(street, x))
		for t in taken:
			close = close or t.distance_to(start) < JUNCTION_CLEAR
		if close:
			continue
		var end := Vector2(x, shore[i].y + reach)
		if not _shallow(g, wl, Vector2(x, shore[i].y), end + Vector2(0.0, FAR_ROW_M), bounds):
			continue
		chosen.append(PackedVector2Array([start, end]))
	chosen.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool: return a[0].x < b[0].x)
	return chosen


## Is the water between `a` and `b` (and 12 m either side) within the piles'
## range, and all of it on the ground's grid?
static func _shallow(g: VillageTerrain, wl: float, a: Vector2, b: Vector2, bounds: Rect2) -> bool:
	var n: int = maxi(1, int(ceil(a.distance_to(b) / 4.0)))
	for k in range(n + 1):
		var p := a.lerp(b, float(k) / float(n))
		for dx in [-12.0, 0.0, 12.0]:
			var q: Vector2 = p + Vector2(dx, 0.0)
			if not bounds.has_point(q) or wl - g.height_at(q) > DEEP_MAX:
				return false
	return true


## The walk along the piers' far ends, on the shoreline's columns between the
## first and the last pier, held to the bend rule. Its ends and the vertices
## at the other piers are the piers' own ends, so every pier meets it.
static func _far_walk(out: VillagePlan, piers: Array[PackedVector2Array]) -> PackedVector2Array:
	var shore: PackedVector2Array = out.shoreline
	var x0: float = piers[0][0].x
	var x1: float = piers[piers.size() - 1][0].x
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	for p in shore:
		if p.x >= x0 - 0.01 and p.x <= x1 + 0.01:
			xs.append(p.x)
			ys.append(p.y + reach_for(out.spec))
	var dx: float = (xs[1] - xs[0]) if xs.size() > 1 else 10.0
	var smooth := VillageShoreForm.limit_bend(ys, dx)
	var walk := PackedVector2Array()
	for i in range(xs.size()):
		walk.append(Vector2(xs[i], smooth[i]))
	# every pier ends on the walk (packed arrays are values: write each back)
	for k in range(piers.size()):
		var p: PackedVector2Array = piers[k]
		for i in range(walk.size()):
			if absf(walk[i].x - p[0].x) < 0.01:
				p[1] = walk[i]
		piers[k] = p
	return walk


# ================================================================ the pile lots

## Place a household on piles over a boardwalk, if it is one and one will
## take it. Returns the distance the lot planner's gradient reads, or -1.
static func place_on_piles(plan: VillagePlan, ctx: Dictionary, job: Dictionary, roads: Array,
		floor_d: float) -> float:
	if plan.spec.form != &"water" or plan.ground == null:
		return -1.0
	if VillageLotPlanner._order_of(job) != VillageLotPlanner._ORDER_HOUSE:
		return -1.0
	var walks: Array = []
	for r in roads:
		if is_boardwalk(plan.roads[r]):
			walks.append(r)
	if walks.is_empty():
		return -1.0
	var piled := pile_job(job)
	if piled.is_empty():
		return -1.0
	return VillageLotPlanner._place_on_road(plan, ctx, piled, walks, floor_d)


## The household as a house on piles: its request asked for piles (a nominal
## depth, a landing no deeper than the gallery) and measured once -- cached on
## the job's own shared cache, so every site retry reuses it. {} for a request
## that cannot stand on piles, or whose door is not on its front.
static func pile_job(job: Dictionary) -> Dictionary:
	var cache: Dictionary = job.get("slope_cache", {})
	if cache.has("piles"):
		return _with_siting(cache["piles"], job)
	var req: BuildingRequest = job["request"]
	var out := {}
	if req.kind in [&"house", &"shop"]:
		var piled := req.copy()
		piled.foundation = &"piles"
		piled.pile_water_m = 1.0
		piled.pile_deck_m = HousePiles.GALLERY_M
		var m := VillageLotPlanner.measure(piled)
		if not m.is_empty() and Vector3(m["placement"]["front"]).is_equal_approx(Vector3(0.0, 0.0, -1.0)):
			var building: GeneratedBuilding = m["building"]
			var plan: HousePlan = building.plan
			var e := plan.entrance()
			if e >= 0 and Vector2(plan.doors[e]["normal"]).is_equal_approx(Vector2(0.0, -1.0)):
				out = m
				out["order"] = job["order"]
				out["class"] = job["class"]
				out["piles"] = true
	cache["piles"] = out
	return _with_siting(out, job)


static func _with_siting(piled: Dictionary, job: Dictionary) -> Dictionary:
	if piled.is_empty():
		return {}
	var out := piled.duplicate()
	out["siting"] = job.get("siting", VillageLotPlanner.SITING_DEFAULT)
	return out


## The lot planner's `_lot_is_legal` for a house on piles: the lot fronts a
## boardwalk and lies wholly on the water, inside the site, clear of every
## ribbon, common, lot and the landmark's ground; the walls inside it, the
## eaves off every carriageway, the neighbours at their fire gaps; and the bed
## under it no deeper than the piles reach. Records `lot["piles"]`.
static func pile_lot_is_legal(plan: VillagePlan, ctx: Dictionary, lot: Dictionary, job: Dictionary,
		gap: float) -> bool:
	if not is_boardwalk(plan.roads[int(lot["road"])]):
		return false
	var poly: PackedVector2Array = lot["poly"]
	if not VillageLotPlanner._inside_site(plan.site, poly):
		return false
	if not wholly_wet(plan, poly):
		return false
	for ribbon in ctx["ribbons"]:
		if VillageLotPlanner._overlaps(poly, ribbon):
			return false
	for c in plan.commons:
		if VillageLotPlanner._overlaps(poly, c["poly"]):
			return false
	if plan.landmark_reserved() and VillageLotPlanner._overlaps(poly, plan.landmark_site["poly"]):
		return false
	for other in plan.lots:
		if VillageLotPlanner._overlaps(poly, other["poly"]):
			return false
	if VillageLotPlanner._corner_blocked(plan, ctx, lot):
		return false
	var xf: Transform3D = VillageLotPlanner._transform_for(lot, job)
	if not VillageLotPlanner._poly_contains(poly, Placement.world_rect(job["placement"], xf, true)):
		return false
	var mine: PackedVector2Array = Placement.world_rect(job["placement"], xf, false)
	for way in ctx["carriageways"]:
		if VillageLotPlanner._overlaps(mine, way):
			return false
	if not VillageLotPlanner._neighbours_clear(plan, job, mine, xf, gap):
		return false
	var reading := pile_reading(plan, poly)
	if reading.is_empty():
		return false
	reading["landing"] = _landing(job, lot, xf)
	reading["reach_m"] = landing_reach(job, lot)
	lot["piles"] = reading
	return true


## Is `poly` wholly on the ground's water (no dry piece over AREA_EPS)?
static func wholly_wet(plan: VillagePlan, poly: PackedVector2Array) -> bool:
	var dry: Array[PackedVector2Array] = [poly]
	for w in plan.water:
		if not bool(w.get("ground", false)):
			continue
		var next: Array[PackedVector2Array] = []
		for piece in dry:
			for rest in Geometry2D.clip_polygons(piece, w["poly"]):
				next.append(rest)
		dry = next
	# what is left is dry: outlines count, holes in them do not
	var total := 0.0
	for piece in dry:
		total += Poly.area(piece) * (-1.0 if Geometry2D.is_polygon_clockwise(piece) else 1.0)
	return total <= VillageLotPlanner.AREA_EPS


## The water under a pile lot: {"deck_m", "water_m" (its depth to the
## deepest bed, snapped up to 0.25 m), "freeboard_m", "bed_m"}; {} when the
## bed anywhere is deeper than the piles reach. The bed is read as the
## village's ground will carve it: never above the water level less CARVE_M.
static func pile_reading(plan: VillagePlan, poly: PackedVector2Array) -> Dictionary:
	var g: VillageTerrain = plan.ground
	var wl: float = g.water_level_m
	var box := Poly.bounding_rect(poly)
	var lo := INF
	var y := box.position.y
	while y <= box.end.y + 1e-6:
		var x := box.position.x
		while x <= box.end.x + 1e-6:
			var p := Vector2(x, y)
			if Poly.contains_point(poly, p, 0.05):
				lo = minf(lo, minf(g.height_at(p), wl - CARVE_M))
			x += BED_STEP
		y += BED_STEP
	for p in poly:
		lo = minf(lo, minf(g.height_at(p), wl - CARVE_M))
	var depth: float = ceil((wl - lo) / 0.25 - 1e-6) * 0.25
	if depth > HousePiles.MAX_WATER_M:
		return {}
	return {"deck_m": deck_level(g), "water_m": depth, "freeboard_m": HousePiles.FREEBOARD_DEFAULT,
		"bed_m": lo}


## How far the house's landing reaches from its entrance wall to the lot's
## front -- the boardwalk's deck edge: the lot's setback, from the walls'
## outer face rather than the measured footprint's.
static func landing_reach(job: Dictionary, lot: Dictionary) -> float:
	var fp: Rect2 = job["placement"]["footprint"]
	var face: float = fp.position.y
	var building: Variant = job.get("building")
	if building != null and building.plan is HousePlan:
		face = HouseGeometry.site_rect(building.plan.spec).position.y
	var front_z: float = fp.position.y - float(lot["setback"])
	return face - front_z


## The landing as a polygon in the plan: the house's width and its gallery,
## from the walls' face out to the lot's front.
static func _landing(job: Dictionary, lot: Dictionary, xf: Transform3D) -> PackedVector2Array:
	var fp: Rect2 = job["placement"]["footprint"]
	var site := fp
	var building: Variant = job.get("building")
	if building != null and building.plan is HousePlan:
		site = HouseGeometry.site_rect(building.plan.spec)
	var front_z: float = fp.position.y - float(lot["setback"])
	var rect := Rect2(Vector2(site.position.x - HousePiles.GALLERY_M, front_z),
		Vector2(site.size.x + 2.0 * HousePiles.GALLERY_M, site.position.y - front_z))
	return VillageLotPlanner._local_rect_world(rect, xf)


## The request a pile lot's house is built from: the measured pile request,
## asked for this lot's depth and a landing to the boardwalk.
static func request_for(job: Dictionary, piles: Dictionary) -> BuildingRequest:
	var out: BuildingRequest = (job["request"] as BuildingRequest).copy()
	out.foundation = &"piles"
	out.pile_water_m = float(piles["water_m"])
	out.pile_freeboard_m = 0.0
	out.pile_deck_m = snappedf(float(piles["reach_m"]), 0.001)
	return out


## The landing of every pile lot, for the walk (VillageNavCheck): floor over
## the water from the boardwalk to the door.
static func landings(plan: VillagePlan) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for lot in plan.lots:
		if lot.has("piles"):
			out.append(lot["piles"]["landing"])
	return out
