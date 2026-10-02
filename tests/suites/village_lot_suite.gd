class_name VillageLotSuite
extends RefCounted
## VIL-004: the lot planner. Fifty seeds of `street` and `green` villages,
## every lot measured against §5's table -- front edge on a road edge, the
## setback band for its class, the fire gap between the MEASURED bounds of
## two neighbours, nothing cut into a road, the common, the water or the
## landmark slot, and no two lots overlapping.
##
## Every number here is read back off the plan and the `placement()` results
## the plan carries, never off the requested envelope: that is the rule the
## whole task turns on, so the suite is careful never to consult
## `BuildingRequest.width` for anything except reporting.
## VILLAGES §5, §6.

const SEEDS := 25            ## per form; 25 street + 25 green = the 50 seeds asked for
const COLLINEAR_EPS := 0.1   ## §5's "the front edge is on a road edge"
const FRONT_SLACK := 1.0     ## §5's "frontage >= building width + 1 m"
const AREA_EPS := 0.05       ## m^2 of overlap that counts as an overlap
const FACE_TOLERANCE_DEG := 15.0
const BAND_SLACK := 0.05     ## floating-point room either side of a setback band


static func run() -> SuiteResult:
	var res := SuiteResult.new("vlot")
	_check_lot_classes(res)
	_check_terrace_rule(res)
	for c in _cases():
		_check_form(res, c)
	_check_water_is_never_a_lot(res)
	_check_manor_gets_its_own_lane(res)
	_check_determinism(res)
	_check_spec_untouched(res)
	return res


## Populations and wealths chosen so the sweep is houses, one shop and the
## small shrine, one storey each: every request goes through
## `BigGlade.generate()`, and a village that earns a church, an inn or a
## manor -- or the second storey a wealth above 0.3 buys -- is several times
## the mesh for exactly the same lot rules. The manor and the landmark lane
## have their own dedicated checks below.
static func _cases() -> Array[Dictionary]:
	return [
		{"form": &"street", "population": 26, "purpose": &"mining", "wealth": 0.2},
		{"form": &"green", "population": 40, "purpose": &"farming", "wealth": 0.2},
	]


static func _spec(p_seed: int, population: int, purpose: StringName, wealth := 0.35) -> VillageSpec:
	var spec := VillageSpec.new(p_seed)
	spec.population = population
	spec.culture = &"english"
	spec.purpose = purpose
	spec.wealth = wealth
	spec.enclosure = &"none"
	spec.water = &"none"
	spec.generate(p_seed)
	return spec


# ------------------------------------------------------------------ the sweep

static func _check_form(res: SuiteResult, c: Dictionary) -> void:
	var form: StringName = c["form"]
	var bad_seeds := 0
	var lots := 0
	var reported := 0
	for s in range(SEEDS):
		var spec: VillageSpec = _spec(9000 + s, int(c["population"]), c["purpose"], float(c["wealth"]))
		res.checked += 1
		if spec.form != form:
			res.fail("seed %d derives form '%s', not '%s'" % [9000 + s, spec.form, form])
			continue
		var plan: VillagePlan = VillageLotPlanner.plan(spec)
		lots += plan.lots.size()
		var problems: Array[String] = judge(plan)
		if plan.lots.is_empty():
			problems.append("no lot was cut at all")
		if not problems.is_empty():
			bad_seeds += 1
			for p in problems:
				if reported < 8:
					res.fail("%s seed %d: %s" % [form, 9000 + s, p])
					reported += 1
	res.note("%s: %d seeds, %d lots, %d seeds with violations" % [form, SEEDS, lots, bad_seeds])


## Every §5 lot rule, measured on one planned village. Empty means clean.
static func judge(plan: VillagePlan) -> Array[String]:
	var out: Array[String] = []
	var edges: Array[Dictionary] = VillageLotPlanner.road_edges(plan)

	# --- one building per lot, and the record carries what §11 promises
	if plan.buildings.size() != plan.lots.size():
		out.append("%d buildings for %d lots" % [plan.buildings.size(), plan.lots.size()])
	var seen := {}
	for b in plan.buildings:
		for key in ["lot", "request", "placement", "transform", "door", "kind", "class"]:
			if not b.has(key):
				out.append("a building record has no '%s'" % key)
				return out
		var li: int = int(b["lot"])
		if li < 0 or li >= plan.lots.size():
			out.append("building lot index %d out of range" % li)
			return out
		if seen.has(li):
			out.append("two buildings on lot %d" % li)
		seen[li] = true

	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var lot: Dictionary = plan.lots[int(b["lot"])]
		var poly: PackedVector2Array = lot["poly"]
		var cls: StringName = b["class"]
		var rule: Dictionary = VillageLotPlanner.LOT_RULES[cls]
		var front: PackedVector2Array = lot["front"]
		var xf: Transform3D = b["transform"]
		var pl: Dictionary = b["placement"]

		# --- a simple polygon with a real area
		if poly.size() < 3 or not Poly.is_simple(poly):
			out.append("lot %d is not a simple polygon" % int(b["lot"]))
			continue
		if Poly.area(poly) < 1.0:
			out.append("lot %d has no area" % int(b["lot"]))

		# --- the front edge is ON an edge of the road it claims
		var e: Dictionary = _edge_under(edges, front, int(lot["road"]))
		if e.is_empty():
			out.append("lot %d front is not on an edge of road %d" % [int(b["lot"]), int(lot["road"])])
			continue

		# --- and it is long enough for the MEASURED building
		var fp: Rect2 = pl["footprint"]
		var bounds: AABB = pl["bounds"]
		var measured_w: float = maxf(fp.size.x, bounds.size.x)
		var front_len: float = front[0].distance_to(front[1])
		if front_len < measured_w + FRONT_SLACK - 1e-3:
			out.append("lot %d frontage %.2f < measured width %.2f + 1" % [
				int(b["lot"]), front_len, measured_w])

		# --- §5 fit, measured: the WALLS stand inside the lot, and the eaves
		# -- which a townhouse's 0-1 m setback band lets reach out over the
		# verge -- never reach over the carriageway itself.
		var lot_rect: Rect2 = Poly.bounding_rect(poly)
		var world_walls: PackedVector2Array = Placement.world_rect(pl, xf, true)
		if VillageLotPlanner.overlap_area(poly, world_walls) < Poly.area(world_walls) - AREA_EPS:
			out.append("lot %d does not contain the measured footprint of its building" % int(b["lot"]))
		var world_bounds: PackedVector2Array = Placement.world_rect(pl, xf, false)
		for r in range(plan.roads.size()):
			var into: float = VillageLotPlanner.overlap_area(world_bounds,
				VillageSitePlanner.road_ribbon(plan.roads[r], false))
			if into > AREA_EPS:
				out.append("%s reaches %.2f m^2 over the carriageway of road %d" % [cls, into, r])
		if lot_rect.size.x < 1.0 or lot_rect.size.y < 1.0:
			out.append("lot %d is degenerate" % int(b["lot"]))

		# --- §5 setback: door to road edge, by class
		var door: Vector3 = b["door"]
		var door_xz := Vector2(door.x, door.z)
		var setback: float = VillageLotPlanner.distance_to_edge_line(e, door_xz)
		if setback < float(rule["set_min"]) - BAND_SLACK or setback > float(rule["set_max"]) + BAND_SLACK:
			out.append("%s setback %.2f outside [%.1f, %.1f]" % [
				cls, setback, rule["set_min"], rule["set_max"]])
		if not Poly.contains_point(poly, door_xz):
			out.append("%s door is not on its own lot" % cls)

		# --- §5 front: the building's local -Z faces the front edge
		var forward: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
		var want: Vector2 = -_inward_normal(front, poly)
		var got := Vector2(forward.x, forward.z).normalized()
		if rad_to_deg(absf(got.angle_to(want))) > FACE_TOLERANCE_DEG:
			out.append("%s faces %.1f deg off its front edge" % [
				cls, rad_to_deg(absf(got.angle_to(want)))])

		# --- §5 corner: a corner lot fronts the more important road
		var mine: int = int(VillageLotPlanner.ROAD_RANK.get(plan.roads[int(lot["road"])]["class"], 9))
		for j in VillageSitePlanner.junctions(plan):
			if _point_to_poly(j["pos"], poly) > VillageLotPlanner.CORNER_RADIUS:
				continue
			for r in j["roads"]:
				var theirs: int = int(VillageLotPlanner.ROAD_RANK.get(plan.roads[int(r)]["class"], 9))
				if theirs < mine:
					out.append("corner lot %d fronts a '%s' where a '%s' meets it" % [
						int(b["lot"]), plan.roads[int(lot["road"])]["class"], plan.roads[int(r)]["class"]])

	# --- nothing is cut into a road, the common, the water or the slot
	for i in range(plan.lots.size()):
		var poly: PackedVector2Array = plan.lots[i]["poly"]
		for r in range(plan.roads.size()):
			var a: float = VillageLotPlanner.overlap_area(poly,
				VillageSitePlanner.road_ribbon(plan.roads[r], true))
			if a > AREA_EPS:
				out.append("lot %d overlaps road %d by %.2f m^2" % [i, r, a])
		for c in plan.commons:
			var ac: float = VillageLotPlanner.overlap_area(poly, c["poly"])
			if ac > AREA_EPS:
				out.append("lot %d overlaps the common by %.2f m^2" % [i, ac])
		for w in plan.water:
			var aw: float = VillageLotPlanner.overlap_area(poly, w["poly"])
			if aw > AREA_EPS:
				out.append("lot %d overlaps water by %.2f m^2" % [i, aw])
		# the landmark's own lot IS the reserved slot -- that one, and only
		# that one, may stand on it.
		if plan.landmark_reserved() and not bool(plan.lots[i].get("landmark", false)):
			var al: float = VillageLotPlanner.overlap_area(poly, plan.landmark_site["poly"])
			if al > AREA_EPS:
				out.append("lot %d overlaps the landmark slot by %.2f m^2" % [i, al])
		for j in range(i + 1, plan.lots.size()):
			var aj: float = VillageLotPlanner.overlap_area(poly, plan.lots[j]["poly"])
			if aj > AREA_EPS:
				out.append("lots %d and %d overlap by %.2f m^2" % [i, j, aj])

	# --- §5 fire gap, between the MEASURED bounds of two buildings
	var terraces: bool = VillageLotPlanner.terraces_allowed(plan.spec)
	for i in range(plan.buildings.size()):
		var bi: Dictionary = plan.buildings[i]
		var ri: PackedVector2Array = Placement.world_rect(bi["placement"], bi["transform"], false)
		for j in range(i + 1, plan.buildings.size()):
			var bj: Dictionary = plan.buildings[j]
			var rj: PackedVector2Array = Placement.world_rect(bj["placement"], bj["transform"], false)
			var d: float = _poly_distance(ri, rj)
			var want_gap: float = maxf(
				VillageLotPlanner.fire_gap(bi["class"], plan.spec),
				VillageLotPlanner.fire_gap(bj["class"], plan.spec))
			if d < want_gap - 1e-3:
				out.append("%s and %s are %.2f m apart, fire gap %.1f" % [
					bi["class"], bj["class"], d, want_gap])
			if d < 0.05 and not terraces:
				out.append("%s and %s touch, but this village may not terrace" % [
					bi["class"], bj["class"]])
	return out


# --------------------------------------------------------------- unit checks

static func _check_lot_classes(res: SuiteResult) -> void:
	var cases := [
		[BuildingRequest.house(1, &"cottage", &"none"), &"cottage"],
		[BuildingRequest.house(1, &"cottage", &"farmer"), &"farm"],
		[BuildingRequest.house(1, &"townhouse", &"none"), &"townhouse"],
		[BuildingRequest.shop(1, &"tavern"), &"shop"],
		[BuildingRequest.church(1), &"church"],
		[BuildingRequest.temple(1), &"church"],
		[BuildingRequest.castle(1), &"manor"],
	]
	for c in cases:
		res.checked += 1
		var got: StringName = VillageLotPlanner.lot_class(c[0])
		if got != c[1]:
			res.fail("lot_class(%s) = '%s', expected '%s'" % [c[0].kind, got, c[1]])
	# the bands themselves are §5's table, and a typo in them would make every
	# other check agree with the wrong number.
	var want_bands := {
		&"cottage": [1.5, 6.0], &"townhouse": [0.0, 1.0], &"farm": [4.0, 12.0],
		&"church": [6.0, 15.0], &"manor": [20.0, 40.0],
	}
	for cls in want_bands:
		res.checked += 1
		var rule: Dictionary = VillageLotPlanner.LOT_RULES[cls]
		if not is_equal_approx(float(rule["set_min"]), float(want_bands[cls][0])) \
				or not is_equal_approx(float(rule["set_max"]), float(want_bands[cls][1])):
			res.fail("%s setback band is [%s, %s], VILLAGES 5 says %s" % [
				cls, rule["set_min"], rule["set_max"], want_bands[cls]])
	res.checked += 1
	if not is_equal_approx(float(VillageLotPlanner.LOT_RULES[&"cottage"]["fire"]), 1.5):
		res.fail("cottage fire gap is not 1.5 m")
	res.checked += 1
	if not is_equal_approx(float(VillageLotPlanner.LOT_RULES[&"farm"]["fire"]), 6.0):
		res.fail("farm fire gap is not 6 m")


## §5: a terrace is allowed only when `wealth >= 0.5` AND `form = planted`.
static func _check_terrace_rule(res: SuiteResult) -> void:
	var rich_street: VillageSpec = _spec(3, 30, &"mining", 0.9)
	res.checked += 1
	if VillageLotPlanner.terraces_allowed(rich_street):
		res.fail("a rich street village is allowed to terrace")
	var planted := VillageSpec.new(4)
	# 150-199: at 200 the `gate` row claims the village instead.
	planted.population = 160
	planted.purpose = &"market"
	planted.wealth = 0.8
	planted.generate(4)
	res.checked += 1
	if planted.form != &"planted":
		res.warn("the planted case derives '%s'; terrace rule untested on it" % planted.form)
	elif not VillageLotPlanner.terraces_allowed(planted):
		res.fail("a rich planted village is not allowed to terrace")
	planted.wealth = 0.3
	res.checked += 1
	if VillageLotPlanner.terraces_allowed(planted):
		res.fail("a poor planted village is allowed to terrace")


## The site planner does not make water yet, so the rule is proved by putting
## a pond on the plan before the lots are cut and asking for it back.
static func _check_water_is_never_a_lot(res: SuiteResult) -> void:
	var spec: VillageSpec = _spec(77, 30, &"mining")
	var plan: VillagePlan = VillageSitePlanner.plan(spec)
	var pond := Rect2(Vector2(plan.site.position.x + 12.0, -30.0), Vector2(26.0, 20.0))
	plan.water.append({"poly": Poly.from_rect(pond), "kind": &"pond"})
	VillageLotPlanner.cut(plan, VillageProgrammer.programme(spec))
	res.checked += 1
	if plan.lots.is_empty():
		res.fail("water case cut no lots at all")
		return
	var worst := 0.0
	for lot in plan.lots:
		worst = maxf(worst, VillageLotPlanner.overlap_area(lot["poly"], Poly.from_rect(pond)))
	if worst > AREA_EPS:
		res.fail("a lot is cut %.2f m^2 into the pond" % worst)
	for p in judge(plan):
		res.fail("water case: " + p)
	res.note("water case: %d lots, none in the pond" % plan.lots.size())


## §6: the manor stands at the head of the village on its OWN lane, >= 20 m
## back. Cut on its own rather than by earning it with a 200-person village,
## because a manor village is forty more houses of mesh for the same rule.
##
## The village is the one that earns a manor: a garrison, which is a gate
## village (VILLAGES §3). A 150-person farming village is a green and earns
## none: its ring street and civic ground left a manor no frontage through any
## of the planner's site retries. It goes through `plan_measured`, the one pipeline, so that the
## site grows as it does for a real lord's village: a bare form's ground is a
## metre or two short of a 52 m deep manor lot beside the ring (EVAL-C11).
## Only the castle is generated here -- the village's own households are
## never programmed -- so this stays one building's worth of mesh.
static func _check_manor_gets_its_own_lane(res: SuiteResult) -> void:
	var spec: VillageSpec = _spec(21, 150, &"garrison")
	var reqs: Array[BuildingRequest] = [BuildingRequest.castle(5, &"norman", 24.0, 26.0, 9.0)]
	var plan: VillagePlan = VillageLotPlanner.plan_measured(spec, VillageLotPlanner.measure_all(reqs))
	res.checked += 1
	if spec.form != &"gate":
		res.fail("a garrison is not a gate village (form '%s')" % spec.form)
		return
	if plan.buildings.size() != 1:
		res.fail("the manor found no frontage")
		return
	var lane: int = int(plan.lots[0]["road"])
	if lane != plan.roads.size() - 1:
		res.fail("the manor fronts road %d, not the lane laid for it (last of %d roads)"
			% [lane, plan.roads.size()])
	elif plan.roads[lane]["class"] != &"lane":
		res.fail("the manor's own road is a '%s'" % plan.roads[lane]["class"])
	for p in judge(plan):
		res.fail("manor case: " + p)
	res.note("manor case: setback band [20, 40] honoured on its own lane")


## The purity rule: the same spec plans the same village, twice.
static func _check_determinism(res: SuiteResult) -> void:
	var a: VillagePlan = VillageLotPlanner.plan(_spec(404, 40, &"farming"))
	var b: VillagePlan = VillageLotPlanner.plan(_spec(404, 40, &"farming"))
	res.checked += 1
	if not a.equals(b):
		res.fail("planning the same spec twice gave two different villages")


static func _check_spec_untouched(res: SuiteResult) -> void:
	var spec: VillageSpec = _spec(505, 30, &"mining")
	var before := {
		"households": spec.households, "form": spec.form, "site": spec.site,
		"programme": spec.programme.size(),
	}
	VillageLotPlanner.plan(spec)
	res.checked += 1
	if spec.households != before["households"] or spec.form != before["form"] \
			or spec.site != before["site"] or spec.programme.size() != before["programme"]:
		res.fail("the lot planner wrote to the spec")


# ------------------------------------------------------------------ geometry

## The road edge `front` lies on, or {} -- both endpoints within 0.1 m of the
## edge's line AND inside its span, on the road the lot claims.
static func _edge_under(edges: Array[Dictionary], front: PackedVector2Array, road: int) -> Dictionary:
	for e in edges:
		if int(e["road"]) != road:
			continue
		var a: Vector2 = e["a"]
		var b: Vector2 = e["b"]
		var d: Vector2 = b - a
		if d.length() < 1e-6:
			continue
		var unit: Vector2 = d.normalized()
		var ok := true
		for p in front:
			if VillageLotPlanner.distance_to_edge_line(e, p) > COLLINEAR_EPS:
				ok = false
				break
		# The front may overhang the segment it is cut from -- a ten-metre
		# cottage does not fit between two samples of a road sampled every
		# ten metres -- but its MIDDLE must stand over that segment, which is
		# what stops "collinear with a road edge" meaning "somewhere on the
		# infinite line that edge happens to lie on".
		if ok:
			var mid: float = ((front[0] + front[1]) * 0.5 - a).dot(unit)
			if mid < -COLLINEAR_EPS or mid > d.length() + COLLINEAR_EPS:
				ok = false
		if ok:
			return e
	return {}


## The unit normal of the front edge pointing INTO the lot.
static func _inward_normal(front: PackedVector2Array, poly: PackedVector2Array) -> Vector2:
	var d: Vector2 = (front[1] - front[0]).normalized()
	var n := Vector2(-d.y, d.x)
	var centre := Vector2.ZERO
	for p in poly:
		centre += p
	centre /= float(poly.size())
	var mid: Vector2 = (front[0] + front[1]) * 0.5
	return n if n.dot(centre - mid) > 0.0 else -n


static func _poly_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if VillageLotPlanner.overlap_area(a, b) > 0.0:
		return 0.0
	var best := INF
	for i in range(a.size()):
		for j in range(b.size()):
			var pair: PackedVector2Array = Geometry2D.get_closest_points_between_segments(
				a[i], a[(i + 1) % a.size()], b[j], b[(j + 1) % b.size()])
			best = minf(best, pair[0].distance_to(pair[1]))
	return best


static func _point_to_poly(p: Vector2, poly: PackedVector2Array) -> float:
	if Poly.contains_point(poly, p):
		return 0.0
	var best := INF
	for i in range(poly.size()):
		best = minf(best, p.distance_to(
			Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return best
