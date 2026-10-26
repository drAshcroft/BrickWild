extends RefCounted
## Suite `vcrossterrain`: the bridges of a village on given ground
## (VTER-CROSSINGS, docs/VILLAGE_TERRAIN.md "Bridges on the ground").
##
##   channel    river_valley's 13 m channel is plan water of kind `river`, with
##              its measured width, and the spec's own river is not laid twice
##   crossings  three roads across it (straight, straight, oblique with a bend)
##              each have a bridge; every abutment's base is within 0.1 m of
##              the emitted ground, the deck clears the water, and the walk
##              crosses on the deck
##   spec river a river the spec draws on a 15 % plane is bridged the same way
##   controls   a floating abutment, a deck dropped into the water, and a
##              deleted crossing are each caught
##   flat       a flat village with a river emits no abutment (its bridge is
##              the old level deck)
##
## Needs no lots: the site plan, its roads and its water are the subject.

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const VT := preload("res://tests/suites/village_terrain_plan_suite.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("vcrossterrain")
	var t0 := Time.get_ticks_msec()
	_river_valley(res)
	_spec_river(res)
	_planned(res)
	_flat(res)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


## The tight grid (fixed centre) leaves the site over the channel; the roads
## are then set by hand across it, so the crossings are a fixed structural case.
static func river_valley_plan(water := &"none") -> VillagePlan:
	var s := VT.spec_for(&"street", null)
	s.water = water
	var flat := VillageSitePlanner.plan_flat(s)
	var half: float = flat.site.size.x * 0.5 + 1.0
	s.terrain = SYNTH.make("river_valley", Rect2(-half, -half, 2.0 * half, 2.0 * half), 5.0)
	var plan := VillageSitePlanner.plan(s)
	var wealth: float = s.wealth
	var roads: Array[Dictionary] = []
	roads.append(VillageSitePlanner._road(PackedVector2Array([Vector2(-44, 30), Vector2(0, 30), Vector2(44, 30)]), &"through", wealth))
	roads.append(VillageSitePlanner._road(PackedVector2Array([Vector2(-20, 30), Vector2(-20, -40)]), &"street", wealth))
	roads.append(VillageSitePlanner._road(PackedVector2Array([Vector2(25, 30), Vector2(25, -40)]), &"street", wealth))
	roads.append(VillageSitePlanner._road(PackedVector2Array([Vector2(2, 30), Vector2(6, 12), Vector2(12, 0), Vector2(8, -14), Vector2(8, -40)]), &"street", wealth))
	plan.roads = roads
	plan.water_crossings = VillageWaterPlan.crossings(plan.water, plan.roads)
	return plan


static func _river_valley(res: SuiteResult) -> void:
	var label := "river_valley"
	var plan := river_valley_plan(&"river")
	res.checked += 1
	var rivers := 0
	var channel := 0.0
	for w in plan.water:
		if w["kind"] == &"river":
			rivers += 1
			channel = float(w.get("width", 0.0))
			if not bool(w.get("ground", false)):
				res.fail("%s: the spec's own river was laid beside the ground's" % label)
	if rivers != 1 or absf(channel - 12.5) > 0.6:
		res.fail("%s: %d river polygons, channel %.1f m (want 1, about 12.5: the 12 m channel and the strand)" % [label, rivers, channel])
	res.checked += 1
	if plan.water_crossings.size() != 3:
		res.fail("%s: %d crossings, want 3" % [label, plan.water_crossings.size()])
		return
	var builder := VillageBuilder.new()
	var mesh := builder.build(plan)
	res.checked += 1
	var comp: Dictionary = ComponentCheck.check(builder, mesh)
	if not comp["ok"]:
		res.fail("%s: components differ from the mesh: %s" % [label, str(comp.get("failures", comp)).left(300)])
	var check := VillageBridgeCheck.new()
	var report: Dictionary = check.check(plan, builder, mesh)
	res.checked += 1
	for f in (report["failures"] as Array).slice(0, 10):
		res.fail("%s: %s" % [label, f])
	var st: Dictionary = report["stats"]
	res.checked += 1
	if int(st["bridges"]) != 3 or int(st["abutments"]) != 6:
		res.fail("%s: judged %d bridges, %d abutments (want 3, 6)" % [label, st["bridges"], st["abutments"]])
	res.note("%s: channel %.1f m; %d bridges, %d abutments, base worst %.3f m, deck over the water %.2f m at least, landing worst %.2f m, spans %s"
		% [label, channel, st["bridges"], st["abutments"], st["base_worst"], st["clear_min"], st["landing_worst"],
			str(plan.water_crossings.map(func(c): return snappedf(Poly.polyline_length(c["points"]), 0.1)))])
	_walk(res, label, plan)
	# the measure the builder used, read back
	var surface := VillageGroundSurface.of(plan)
	for i in range(plan.water_crossings.size()):
		var m := VillageBridge.measure(surface, plan.water_crossings[i])
		res.checked += 1
		if float(m["wet_m"]) < 8.0 or float(m["span_m"]) < float(m["wet_m"]):
			res.fail("%s: crossing %d measured wet %.1f m of a span of %.1f m" % [label, i, m["wet_m"], m["span_m"]])
	_controls(res, plan, builder, mesh)


static func _walk(res: SuiteResult, label: String, plan: VillagePlan) -> void:
	for i in range(plan.water_crossings.size()):
		var c: Dictionary = plan.water_crossings[i]
		var pts: PackedVector2Array = c["points"]
		var walk := VillageNavCheck.build_grid(plan)
		var start: Vector2 = pts[0].lerp(pts[0] + (pts[0] - pts[1]).normalized() * 3.0, 1.0)
		var finish: Vector2 = pts[-1] + (pts[-1] - pts[-2]).normalized() * 3.0
		res.checked += 1
		var ok: bool = walk.flood_from(start) and walk.reached(Rect2(finish - Vector2.ONE * 0.2, Vector2.ONE * 0.4))
		if not ok:
			res.fail("%s: the walk does not cross bridge %d from %s to %s" % [label, i, start, finish])
	# and with the crossings taken up there is no way across
	var gone := river_valley_plan(&"river")
	gone.water_crossings.clear()
	var walk := VillageNavCheck.build_grid(gone)
	var c: Dictionary = plan.water_crossings[1]
	var pts: PackedVector2Array = c["points"]
	walk.flood_from(pts[0] + (pts[0] - pts[1]).normalized() * 3.0)
	res.checked += 1
	if walk.reached(Rect2(pts[-1] + (pts[-1] - pts[-2]).normalized() * 3.0 - Vector2.ONE * 0.2, Vector2.ONE * 0.4)):
		res.fail("%s: the river is crossed with no bridge" % label)


## One negative control per rule the bridge check holds.
static func _controls(res: SuiteResult, plan: VillagePlan, builder: VillageBuilder, mesh: ArrayMesh) -> void:
	var check := VillageBridgeCheck.new()
	var rows: Array = builder.component_log
	# 1. an abutment lifted off the ground
	var lifted: int = -1
	for k in range(rows.size()):
		if rows[k]["role"] == "bridge_abutment":
			lifted = k
			break
	var saved: Transform3D = rows[lifted]["xf"]
	var moved := saved
	moved.origin.y += 0.5
	rows[lifted]["xf"] = moved
	var report: Dictionary = check.check(plan, builder, mesh)
	rows[lifted]["xf"] = saved
	res.checked += 1
	if report["ok"]:
		res.fail("control: an abutment 0.5 m off the ground was accepted")
	# 2. a deck dropped to the water
	var deck: int = -1
	var points_saved: PackedVector3Array
	for k in range(rows.size()):
		if rows[k]["role"] == "crossing_deck" and String(rows[k]["host"]) == "bridge0":
			deck = k
			points_saved = rows[k]["points"]
			break
	if deck >= 0:
		var low := PackedVector3Array()
		for v in points_saved:
			low.append(Vector3(v.x, v.y - 1.5, v.z))
		rows[deck]["points"] = low
		report = check.check(plan, builder, mesh)
		rows[deck]["points"] = points_saved
		res.checked += 1
		if report["ok"]:
			res.fail("control: a deck 1.5 m lower, in the water, was accepted")
	# 3. an abutment removed
	var removed: Dictionary = rows[lifted]
	rows.remove_at(lifted)
	report = check.check(plan, builder, mesh)
	rows.insert(lifted, removed)
	res.checked += 1
	if report["ok"]:
		res.fail("control: a bridge with one abutment was accepted")
	report = check.check(plan, builder, mesh)
	res.checked += 1
	if not report["ok"]:
		res.fail("control: the controls left the bridges damaged: %s" % str(report["failures"]).left(200))


## A river the spec draws on a 15 % plane: no channel in the ground, so the
## spec's strip is laid on it and bridged like the ground's own.
static func _spec_river(res: SuiteResult) -> void:
	var label := "plane_15/river"
	var s := VT.spec_for(&"green", VT.terrain("plane_15"))
	s.water = &"river"
	var plan := VillageSitePlanner.plan(s)
	res.checked += 1
	if plan.ground == null:
		res.fail("%s: not sited" % label)
		return
	var n := plan.water_crossings.size()
	res.note("%s: %d crossings" % [label, n])
	var builder := VillageBuilder.new()
	var mesh := builder.build(plan)
	var report: Dictionary = VillageBridgeCheck.new().check(plan, builder, mesh)
	res.checked += 1
	for f in (report["failures"] as Array).slice(0, 10):
		res.fail("%s: %s" % [label, f])
	var st: Dictionary = report["stats"]
	res.note("%s: %d bridges, %d abutments, base worst %.3f m, clearance %.2f m" % [label, st["bridges"], st["abutments"], st["base_worst"], st["clear_min"]])
	res.checked += 1
	if int(st["bridges"]) < 1:
		res.fail("%s: the river is crossed by no bridge, nothing was judged" % label)
	res.checked += 1
	if int(st["abutments"]) != 2 * int(st["bridges"]):
		res.fail("%s: %d abutments for %d bridges" % [label, st["abutments"], st["bridges"]])


## The siting's own choice on river_valley (the whole 800 m grid, the form
## free to move off the channel): whatever crossings it has are judged. The
## roads run the contour and the siting keeps the village beside the channel,
## so there may be none -- noted, not required (docs: what is open).
static func _planned(res: SuiteResult) -> void:
	for form in [&"crossroads", &"green"]:
		var s := VT.spec_for(form, SYNTH.make("river_valley"))
		s.water = &"river"
		var plan := VillageSitePlanner.plan(s)
		var builder := VillageBuilder.new()
		var mesh := builder.build(plan)
		var report: Dictionary = VillageBridgeCheck.new().check(plan, builder, mesh)
		res.checked += 1
		for f in (report["failures"] as Array).slice(0, 6):
			res.fail("planned %s: %s" % [form, f])
		res.note("planned river_valley/%s: %d water, %d crossings, %d bridges judged"
			% [form, plan.water.size(), plan.water_crossings.size(), report["stats"]["bridges"]])


## Without ground nothing changes: a flat village with a river builds the old
## level deck and no abutment.
static func _flat(res: SuiteResult) -> void:
	var s := VT.spec_for(&"green", null)
	s.water = &"river"
	var plan := VillageSitePlanner.plan(s)
	var builder := VillageBuilder.new()
	builder.build(plan)
	res.checked += 1
	if plan.water_crossings.is_empty():
		res.fail("flat: no crossing to judge")
	res.checked += 1
	if not builder.components("bridge_abutment").is_empty():
		res.fail("flat: a flat village emitted an abutment")
