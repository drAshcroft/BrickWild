class_name VillageSiteSuite
extends RefCounted
## VIL-003: the site planner lays a through road that goes somewhere, a
## common on it, the landmark slot before any lot, and the streets and lanes
## of the `street` and `green` forms -- every one of them measured, on 50
## seeds of each form, in the vocabulary RoadCheck will later use.
## VILLAGES §2, §3, §5, §6.

const SEEDS := 50

const MAX_TURN_PER_20M_DEG := 25.0
const BEND_RADIUS_FACTOR := 3.0
const JUNCTION_MIN_ANGLE_DEG := 30.0
const JUNCTION_MIN_SPACING := 8.0
const COMMON_TO_ROAD_MAX := 15.0


static func run() -> SuiteResult:
	var res := SuiteResult.new("vsite")
	_check_forms_are_what_we_think(res)
	for form_case in _cases():
		_check_form(res, form_case)
	_check_hamlet_common_is_the_well(res)
	_check_determinism(res)
	_check_spec_untouched(res)
	return res


## The two configurations that derive the two forms this planner owns. Note
## `street` needs a purpose the `green` and `round` rows do not claim.
static func _cases() -> Array[Dictionary]:
	return [
		{"form": &"street", "population": 70, "purpose": &"forest"},
		{"form": &"green", "population": 80, "purpose": &"farming"},
	]


static func _spec(p_seed: int, population: int, purpose: StringName) -> VillageSpec:
	var spec := VillageSpec.new(p_seed)
	spec.population = population
	spec.culture = &"english"
	spec.purpose = purpose
	spec.wealth = 0.4
	spec.enclosure = &"none"
	spec.water = &"none"
	spec.generate(p_seed)
	return spec


static func _check_forms_are_what_we_think(res: SuiteResult) -> void:
	for c in _cases():
		var spec: VillageSpec = _spec(1, int(c["population"]), c["purpose"])
		res.checked += 1
		if spec.form != c["form"]:
			res.fail("case %s derives form '%s', not '%s'" % [c["purpose"], spec.form, c["form"]])
	var hamlet: VillageSpec = _spec(1, 18, &"mining")
	res.checked += 1
	if hamlet.form != &"street":
		res.fail("hamlet case derives form '%s', not 'street'" % hamlet.form)


static func _check_form(res: SuiteResult, c: Dictionary) -> void:
	var form: StringName = c["form"]
	var failures := 0
	for s in range(SEEDS):
		var spec: VillageSpec = _spec(s, int(c["population"]), c["purpose"])
		var plan: VillagePlan = VillageSitePlanner.plan(spec)
		var problems: Array[String] = _judge(plan, spec)
		res.checked += 1
		if not problems.is_empty():
			failures += 1
			if failures <= 3:
				res.fail("%s seed %d: %s" % [form, s, "; ".join(problems)])
	if failures > 3:
		res.fail("%s: %d of %d seeds failed" % [form, failures, SEEDS])
	res.note("%s: %d seeds planned, %d clean" % [form, SEEDS, SEEDS - failures])


## Every acceptance criterion of VIL-003, on one plan.
static func _judge(plan: VillagePlan, spec: VillageSpec) -> Array[String]:
	var out: Array[String] = []
	var site: Rect2 = plan.site
	if site.size.x <= 0.0:
		out.append("no site")
		return out
	if site.size.x > 400.0 or site.size.y > 400.0:
		out.append("site %s bigger than 400 m" % site.size)

	# --- exactly one through road, ends on two different sides -------------
	var through_ids: Array[int] = plan.roads_of_class(&"through")
	if through_ids.size() != 1:
		out.append("%d through roads" % through_ids.size())
		return out
	var through: Dictionary = plan.roads[through_ids[0]]
	var pts: PackedVector2Array = through["points"]
	var side_a: String = _side_of(site, pts[0])
	var side_b: String = _side_of(site, pts[pts.size() - 1])
	if side_a == "" or side_b == "":
		out.append("through ends not on the boundary (%s -> %s)" % [pts[0], pts[pts.size() - 1]])
	elif side_a == side_b:
		out.append("through enters and leaves the same side (%s)" % side_a)

	# --- never straight across ---------------------------------------------
	if VillageSitePlanner.bow(pts) < VillageSitePlanner.MIN_BOW_M:
		out.append("through road is straight across (bow %.2f m)" % VillageSitePlanner.bow(pts))

	# --- classes carry width and verge per the S5 table --------------------
	for r in plan.roads:
		var cls: StringName = r["class"]
		if not VillageSitePlanner.ROAD_CLASSES.has(cls):
			out.append("unknown road class '%s'" % cls)
			continue
		var row: Dictionary = VillageSitePlanner.ROAD_CLASSES[cls]
		if not is_equal_approx(float(r["width"]), float(row["width"])):
			out.append("%s width %.2f != %.2f" % [cls, r["width"], row["width"]])
		if not is_equal_approx(float(r["verge"]), float(row["verge"])):
			out.append("%s verge %.2f != %.2f" % [cls, r["verge"], row["verge"]])

	# --- bends --------------------------------------------------------------
	for r in plan.roads:
		var problem: String = _bend_problem(r)
		if problem != "":
			out.append(problem)

	# --- ribbons are simple polygons ---------------------------------------
	for r in plan.roads:
		for with_verge in [false, true]:
			var ribbon: PackedVector2Array = VillageSitePlanner.road_ribbon(r, with_verge)
			if ribbon.size() < 4:
				out.append("%s ribbon degenerate" % r["class"])
			elif not Poly.is_simple(ribbon):
				out.append("%s ribbon self-intersects (verge %s)" % [r["class"], with_verge])

	# --- one component ------------------------------------------------------
	var comps: int = VillageSitePlanner.road_components(plan)
	if comps != 1:
		out.append("road graph has %d components" % comps)

	# --- junctions ----------------------------------------------------------
	var js: Array[Dictionary] = VillageSitePlanner.junctions(plan)
	if plan.roads.size() > 1 and js.is_empty():
		out.append("no junctions for %d roads" % plan.roads.size())
	for j in js:
		var dirs: Array = j["dirs"]
		for a in range(dirs.size()):
			for b in range(a + 1, dirs.size()):
				var ang: float = rad_to_deg(absf((dirs[a] as Vector2).angle_to(dirs[b] as Vector2)))
				if ang < JUNCTION_MIN_ANGLE_DEG:
					out.append("junction at %s has a %.1f deg corner" % [j["pos"], ang])
	for a in range(js.size()):
		for b in range(a + 1, js.size()):
			var d: float = (js[a]["pos"] as Vector2).distance_to(js[b]["pos"])
			if d < JUNCTION_MIN_SPACING:
				out.append("junctions %.2f m apart" % d)

	# --- the common ---------------------------------------------------------
	if plan.commons.size() != 1:
		out.append("%d commons" % plan.commons.size())
	else:
		var common: PackedVector2Array = plan.commons[0]["poly"]
		var area: float = Poly.area(common)
		var min_area: float = (VillageSitePlanner.HAMLET_COMMON_AREA
			if spec.population < VillageSitePlanner.HAMLET_POPULATION
			else VillageSitePlanner.COMMON_MIN_AREA)
		if area < min_area - 0.01:
			out.append("common %.1f m2 < %.1f" % [area, min_area])
		if not _poly_inside(common, site):
			out.append("common leaves the site")
		# within 15 m of the through road, and clear of every carriageway
		if _poly_to_polyline(common, pts) > COMMON_TO_ROAD_MAX:
			out.append("common %.1f m from the through road" % _poly_to_polyline(common, pts))
		for r in plan.roads:
			var ribbon: PackedVector2Array = VillageSitePlanner.road_ribbon(r, true)
			if Poly.intersection_area(common, ribbon) > 0.01:
				out.append("common overlaps a %s" % r["class"])

	# --- the landmark slot, before any lot ---------------------------------
	if not plan.landmark_reserved():
		out.append("no landmark_site reserved")
	else:
		var lm: PackedVector2Array = plan.landmark_site["poly"]
		if Poly.area(lm) < 100.0:
			out.append("landmark_site only %.1f m2" % Poly.area(lm))
		if not _poly_inside(lm, site):
			out.append("landmark_site leaves the site")
		if not plan.commons.is_empty() and Poly.intersection_area(lm, plan.commons[0]["poly"]) > 0.01:
			out.append("landmark_site overlaps the common")
		for r in plan.roads:
			if Poly.intersection_area(lm, VillageSitePlanner.road_ribbon(r, true)) > 0.01:
				out.append("landmark_site overlaps a %s" % r["class"])
	if not plan.lots.is_empty():
		out.append("site planner cut %d lots (that is VIL-004's job)" % plan.lots.size())

	# --- everything on the ground ------------------------------------------
	for r in plan.roads:
		for p in r["points"]:
			if not site.grow(0.01).has_point(p):
				out.append("%s leaves the site at %s" % [r["class"], p])
				break

	# --- the form's own shape ----------------------------------------------
	if spec.form == &"green":
		if plan.roads_of_class(&"street").size() != 3:
			out.append("green form has %d streets, want a ring of 3" % plan.roads_of_class(&"street").size())
	else:
		if plan.roads_of_class(&"lane").is_empty():
			out.append("street form has no lanes")
		for i in plan.roads_of_class(&"lane"):
			var length: float = Poly.polyline_length(plan.roads[i]["points"])
			if length > 40.0:
				out.append("dead-end lane %.1f m > 40 m" % length)
	return out


## §5's two bend rules, on one road: `<= 25 deg per 20 m` measured over
## sliding arc-length windows, and `bend radius >= 3 x width` at every
## interior vertex.
static func _bend_problem(road: Dictionary) -> String:
	var pts: PackedVector2Array = road["points"]
	if pts.size() < 3:
		return ""
	var width: float = float(road["width"])
	var arc := PackedFloat32Array()
	arc.append(0.0)
	for i in range(1, pts.size()):
		arc.append(arc[i - 1] + pts[i - 1].distance_to(pts[i]))
	var turns: PackedFloat32Array = Poly.turns(pts)
	for i in range(turns.size()):
		var total := 0.0
		for j in range(i, turns.size()):
			if arc[j + 1] - arc[i + 1] > 20.0:
				break
			total += turns[j]
		if rad_to_deg(total) > MAX_TURN_PER_20M_DEG:
			return "%s turns %.1f deg in 20 m" % [road["class"], rad_to_deg(total)]
	for i in range(1, pts.size() - 1):
		var r: float = Poly.bend_radius(pts[i - 1], pts[i], pts[i + 1])
		if r < BEND_RADIUS_FACTOR * width:
			return "%s bend radius %.1f m < %.1f" % [road["class"], r, BEND_RADIUS_FACTOR * width]
	return ""


## §3: "a hamlet is the street form below 25 people with the common shrunk to
## the well".
static func _check_hamlet_common_is_the_well(res: SuiteResult) -> void:
	var big_seen := false
	for s in range(SEEDS):
		var spec: VillageSpec = _spec(s, 18, &"mining")
		var plan: VillagePlan = VillageSitePlanner.plan(spec)
		res.checked += 1
		var problems: Array[String] = _judge(plan, spec)
		if not problems.is_empty():
			res.fail("hamlet seed %d: %s" % [s, "; ".join(problems)])
			break
		var area: float = Poly.area(plan.commons[0]["poly"])
		if area > 60.0:
			big_seen = true
	res.checked += 1
	if big_seen:
		res.fail("a hamlet's common was not shrunk to the well")


static func _check_determinism(res: SuiteResult) -> void:
	for c in _cases():
		for s in [0, 7, 41]:
			var a: VillagePlan = VillageSitePlanner.plan(_spec(s, int(c["population"]), c["purpose"]))
			var b: VillagePlan = VillageSitePlanner.plan(_spec(s, int(c["population"]), c["purpose"]))
			res.checked += 1
			if not a.equals(b):
				res.fail("%s seed %d is not deterministic" % [c["form"], s])


## The purity rule's other half: planning does not modify the spec.
static func _check_spec_untouched(res: SuiteResult) -> void:
	var spec: VillageSpec = _spec(3, 80, &"farming")
	var before: Rect2 = spec.site
	var households: int = spec.households
	var form: StringName = spec.form
	VillageSitePlanner.plan(spec)
	res.checked += 1
	if spec.site != before or spec.households != households or spec.form != form:
		res.fail("planning modified the spec")


# ---------------------------------------------------------------- geometry

static func _side_of(site: Rect2, p: Vector2, eps := 0.01) -> String:
	if absf(p.x - site.position.x) <= eps:
		return "west"
	if absf(p.x - site.end.x) <= eps:
		return "east"
	if absf(p.y - site.position.y) <= eps:
		return "south"
	if absf(p.y - site.end.y) <= eps:
		return "north"
	return ""


static func _poly_inside(poly: PackedVector2Array, site: Rect2) -> bool:
	var grown: Rect2 = site.grow(0.01)
	for p in poly:
		if not grown.has_point(p):
			return false
	return true


## Shortest distance from any vertex of `poly` to the polyline `line`.
static func _poly_to_polyline(poly: PackedVector2Array, line: PackedVector2Array) -> float:
	var best: float = INF
	for p in poly:
		for i in range(1, line.size()):
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i - 1], line[i])))
	return best
