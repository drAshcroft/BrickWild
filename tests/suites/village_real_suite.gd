extends RefCounted
## VREAL (`vreal`): planned villages against the historic survey
## (tests/fixtures/settlements/layout_stats.json, 46 sites; docs/VILLAGE_REAL_LAYOUT.md).
## The programme's sizes and types are judged in `village`
## (`_check_programme_real_sizes`); this is the plan.
##
## Per open case, one measured programme, planned as shipped:
##   touching   the share of buildings whose nearest neighbour's eaves are
##              within half a metre is inside the culture's band (BANDS: the
##              p10-p90 of the historic sites' shares -- one planned village is
##              one draw, judged against the spread of real villages)
##   loneliest  no building stands farther than LONELY_MAX from its nearest
##              neighbour (the survey's loneliest building: median 23.5 m,
##              p90 33 m)
##   gradient   house size against distance from the common is no tighter a
##              ring than any real village (Monteriggioni, -0.70, is the
##              strongest; RING_MIN) and still meets VillagePlaceCheck's
##              `gradient` (<= -0.3)
##   lot rules  VillageLotSuite.judge and VillageLotCheck hold, and every party
##              side is recorded on both lots
## and the same jobs planned the old way, which must FAIL: packing off is
## short of the touching band, the strict biggest-first order is a ring.
##
## The enclosed case: the hedge stands at the real town wall's distance from
## the houses (p25-p75 4.0-9.3 m), and the old hull edge of the same plan
## stands at least WALL_CONTROL_M farther out (the control: the measure sees
## the difference).
##
## `REAL_CASE=frankish` runs one case.

const BANDS := {
	&"frankish": Vector2(0.31, 0.88),
	&"mediterranean": Vector2(0.13, 0.80),
	&"norse": Vector2(0.06, 0.33),
}
const BAND_SLACK := 0.0
const TOUCH_M := 0.5
const LONELY_MAX := 33.0
const RING_MIN := VillageLotPlanner.GRADIENT_RING
const WALL_P50 := Vector2(4.0, 9.3)
const WALL_SLACK := 1.5
const WALL_CONTROL_M := 2.0

const CASES := [
	{"culture": &"frankish", "purpose": &"market", "population": 60, "seed": 7101},
	{"culture": &"mediterranean", "purpose": &"farming", "population": 50, "seed": 7102},
	{"culture": &"norse", "purpose": &"farming", "population": 50, "seed": 7103},
	{"culture": &"english", "purpose": &"market", "population": 90, "seed": 7104, "enclosure": &"hedge"},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("vreal")
	var t0 := Time.get_ticks_msec()
	var only := OS.get_environment("REAL_CASE")
	for c in CASES:
		if only != "" and String(c["culture"]) != only:
			continue
		_case(res, c)
	_defaults()
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func _defaults() -> void:
	VillageLotPlanner.pack_enabled = true
	VillageLotPlanner.join_share_k = VillageLotPlanner.JOIN_SHARE_K
	VillageLotPlanner.gradient_jitter = VillageLotPlanner.GRADIENT_JITTER
	VillageLotPlanner.gradient_mode = VillageLotPlanner.GRADIENT_MODE
	VillageLotPlanner.gradient_floor_filters = false


static func _spec(c: Dictionary) -> VillageSpec:
	var spec := VillageSpec.new(int(c["seed"]))
	spec.population = int(c["population"])
	spec.culture = c["culture"]
	spec.purpose = c["purpose"]
	spec.wealth = 0.5
	spec.enclosure = c.get("enclosure", &"none")
	spec.water = &"none"
	spec.generate(int(c["seed"]))
	return spec


static func _case(res: SuiteResult, c: Dictionary) -> void:
	var culture: StringName = c["culture"]
	var spec := _spec(c)
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(spec))
	_defaults()
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	var m := measure(plan)
	var label := "%s %s" % [culture, String(spec.form)]
	res.checked += 1
	if plan.buildings.size() < jobs.size():
		res.fail("%s: housed %d of %d" % [label, plan.buildings.size(), jobs.size()])
	res.checked += 1
	if float(m["loneliest"]) > LONELY_MAX:
		res.fail("%s: a building stands %.1f m from its nearest neighbour, the real loneliest p90 is %.0f"
			% [label, m["loneliest"], LONELY_MAX])
	res.checked += 1
	for p in VillageLotSuite.judge(plan):
		res.fail("%s lot rule: %s" % [label, p])
	res.checked += 1
	for f in VillageLotCheck.new().check(plan)["failures"]:
		res.fail("%s lot check: %s" % [label, f])
	res.checked += 1
	for p in party_problems(plan):
		res.fail("%s party: %s" % [label, p])
	if m["houses"] >= 8:
		res.checked += 1
		if float(m["rho"]) < RING_MIN or float(m["rho"]) > VillagePlaceCheck.GRADIENT_MAX:
			res.fail("%s: size against distance from the common %.2f, want %.2f to %.1f"
				% [label, m["rho"], RING_MIN, VillagePlaceCheck.GRADIENT_MAX])
	res.note("%-22s %d buildings on %.0fx%.0f m: touching %.2f, gap p50 %.1f m, loneliest %.1f m, gradient %.2f over %d houses, %d party sides" % [
		label, plan.buildings.size(), plan.site.size.x, plan.site.size.y, m["touching"], m["gap_p50"],
		m["loneliest"], m["rho"], m["houses"], m["party"]])
	if BANDS.has(culture):
		var band: Vector2 = BANDS[culture]
		var lo: float = maxf(0.0, band.x - BAND_SLACK)
		var hi: float = band.y + BAND_SLACK
		res.checked += 1
		if float(m["touching"]) < lo or float(m["touching"]) > hi:
			res.fail("%s: touching share %.2f, real band %.2f-%.2f" % [label, m["touching"], lo, hi])
		# control: the same jobs, packing off -- short of the band
		VillageLotPlanner.pack_enabled = false
		var plain := measure(VillageLotPlanner.plan_measured(spec, jobs))
		_defaults()
		res.checked += 1
		if float(plain["touching"]) >= lo:
			res.fail("control %s: packing off still touches %.2f, inside the band" % [label, plain["touching"]])
		res.note("control %-14s packing off (must fall short of %.2f): touching %.2f, gap p50 %.1f m" % [
			label, lo, plain["touching"], plain["gap_p50"]])
	if culture == &"frankish":
		# control: the old planner -- strict biggest-first, the farthest bigger
		# house as a floor that FILTERS, no packing -- is the ring no real
		# village is (the walk stops read -0.88 to -0.95 so)
		VillageLotPlanner.pack_enabled = false
		VillageLotPlanner.gradient_jitter = 0.0
		VillageLotPlanner.gradient_mode = &"max"
		VillageLotPlanner.gradient_floor_filters = true
		var strict := measure(VillageLotPlanner.plan_measured(spec, jobs))
		_defaults()
		res.checked += 1
		if float(strict["rho"]) >= RING_MIN:
			res.fail("control %s: the old order reads %.2f, not a ring past %.2f" % [label, strict["rho"], RING_MIN])
		res.note("control %-14s old order, no packing (must ring past %.2f): gradient %.2f" % [label, RING_MIN, strict["rho"]])
	if spec.enclosure != &"none":
		var wall := wall_distances(plan, plan.enclosure)
		var old := wall_distances(plan, VillageEnclosurePlan.build(plan, VillageEnclosurePlan.EDGE_BAND, false)["edge"])
		res.checked += 1
		if wall.is_empty() or float(wall["p50"]) < WALL_P50.x - WALL_SLACK or float(wall["p50"]) > WALL_P50.y + WALL_SLACK:
			res.fail("%s: the %s stands %s m (median) from the houses, the real wall %.1f-%.1f"
				% [label, String(spec.enclosure), str(wall.get("p50", "no")), WALL_P50.x, WALL_P50.y])
		res.checked += 1
		if old.is_empty() or wall.is_empty() or float(old["p50"]) < float(wall["p50"]) + WALL_CONTROL_M:
			res.fail("control %s: the old hull edge (%s m) is not %.0f m farther out than the %s"
				% [label, str(old.get("p50", "no")), WALL_CONTROL_M, String(spec.enclosure)])
		res.note("%-22s %s: median %.1f m, p90 %.1f m from a house; old hull edge (control) %.1f m" % [
			label, String(spec.enclosure), wall.get("p50", -1.0), wall.get("p90", -1.0), old.get("p50", -1.0)])


## The share of buildings whose nearest neighbour's eaves are within
## `TOUCH_M`, the median and the largest of those nearest gaps, the party
## sides recorded, and the Spearman of house size against distance from the
## common over the houses VillagePlaceCheck's `gradient` judges.
static func measure(plan: VillagePlan) -> Dictionary:
	var polys: Array[PackedVector2Array] = []
	for b in plan.buildings:
		polys.append(VillageMeasure.bounds_poly(b))
	var gaps: Array[float] = []
	var touching := 0
	for i in polys.size():
		var best := INF
		for j in polys.size():
			if i != j:
				best = minf(best, VillageMeasure.poly_distance(polys[i], polys[j]))
		gaps.append(best)
		if best < TOUCH_M:
			touching += 1
	gaps.sort()
	var party := 0
	for lot in plan.lots:
		party += (lot.get("party", []) as Array).size()
	var cc: Vector2 = VillageMeasure.common_centre(plan)
	var areas: Array = []
	var dists: Array = []
	for i in plan.buildings_of_kind(&"house"):
		var b: Dictionary = plan.buildings[i]
		if b["class"] == &"farm":
			continue
		var fp: Rect2 = b["placement"]["footprint"]
		areas.append(fp.size.x * fp.size.y)
		dists.append(VillageMeasure.centre(VillageMeasure.footprint_poly(b)).distance_to(cc))
	return {
		"touching": float(touching) / maxf(1.0, float(polys.size())),
		"gap_p50": gaps[gaps.size() / 2] if not gaps.is_empty() else INF,
		"loneliest": gaps.back() if not gaps.is_empty() else INF,
		"party": party,
		"houses": areas.size(),
		"rho": VillageMeasure.spearman(areas, dists) if areas.size() >= 3 else 0.0,
	}


## How far the enclosure, sampled every 5 m, stands from the nearest building.
static func wall_distances(plan: VillagePlan, edge: PackedVector2Array) -> Dictionary:
	if edge.size() < 3:
		return {}
	var polys: Array[PackedVector2Array] = []
	for b in plan.buildings:
		polys.append(VillageMeasure.bounds_poly(b))
	var ds: Array[float] = []
	for k in edge.size():
		var a: Vector2 = edge[k]
		var b: Vector2 = edge[(k + 1) % edge.size()]
		var steps: int = maxi(1, int(ceil(a.distance_to(b) / 5.0)))
		for s in steps:
			var p: Vector2 = a.lerp(b, float(s) / float(steps))
			var best := INF
			for poly in polys:
				best = minf(best, VillageMeasure.point_to_poly(p, poly))
			ds.append(best)
	ds.sort()
	return {"p50": ds[ds.size() / 2], "p90": ds[int(ds.size() * 0.9)]}


## Every party side is recorded on both lots, the two buildings' eaves are
## near, and the two lots meet along one side.
static func party_problems(plan: VillagePlan) -> Array[String]:
	var out: Array[String] = []
	var building_of := {}
	for i in plan.buildings.size():
		building_of[int(plan.buildings[i]["lot"])] = i
	for li in plan.lots.size():
		for lj in plan.lots[li].get("party", []):
			if li not in (plan.lots[int(lj)].get("party", []) as Array):
				out.append("lot %d names %d as its party but not the other way" % [li, lj])
				continue
			if not building_of.has(li) or not building_of.has(int(lj)):
				out.append("party lots %d and %d are not both built" % [li, lj])
				continue
			var d := VillageMeasure.poly_distance(VillageMeasure.bounds_poly(plan.buildings[building_of[li]]),
				VillageMeasure.bounds_poly(plan.buildings[building_of[int(lj)]]))
			if d > TOUCH_M:
				out.append("party lots %d and %d stand %.2f m apart" % [li, lj, d])
			if Geometry2D.intersect_polygons(Poly.offset(plan.lots[li]["poly"], 0.02), plan.lots[int(lj)]["poly"]).is_empty():
				out.append("party lots %d and %d do not meet" % [li, lj])
	return out
