extends RefCounted
## `lane:village-terrain`: the bounded terrain gate (VTER-LOTS, VTER-ROADS,
## VTER-SITING, VTER-STEPS-NAV; docs/VILLAGE_TERRAIN.md).
##
## One small village (30 people, its buildings measured once) planned on the
## synthetic landforms with a known answer and on three real 30 m fixtures.
## Thirty, not vtplan's fifty: measuring the fifty-person programme's sixteen
## buildings costs 89 s on this host before the first plan (the thirty-person
## one nine buildings, 54 s), and fifty people's six plans put the lane over
## the five-minute cap. Every rule below is unchanged by the population.
## Every case runs the five rules this lane exists for:
##
##   (a) grades      every road's grade_max on the plan's own ground, and again
##                   on the caller's grid at the carried points, is within its
##                   class's cap (through/lane 12 %, street/track/path 30 %)
##   (b) fall        every lot has a platform, its building asks for no more
##                   fall than its family stands on in a village, and the
##                   request the fall produces is still accepted
## (c) walk        on the stair village (Manarola, crossroads): stair streets
##                   have treads, lots have a way in, every gate and door is
##                   on one 3D mesh, and NavigationServer3D reaches every door
##   (d) wet         no lot, building, common or road end stands on standing
##                   water
##   (e) siting      the village says where it stands (anchor, yaw), its
##                   corners are on the grid, the frame view reads the
##                   caller's ground there, the common is on the level and
##                   dry, and a grid that only just covers the site keeps the
##                   caller's centre and turns only as far as it still covers
##
## The synthetic cases are `plane_30` (the 30 % plane: grades, contour siting
## and fall), `lake_shore` (wet ground at a known water level) and
## `cliff_band` (a 15 m step). The real ones are Manarola (a crossroads: the
## one Manarola form of five tried at thirty people that still lays a stair
## street, with five access flights), Masouleh (a 40-60 % hillside: the fall
## cap) and Monpazier (a gentle bastide as the third real fixture).
##
## Every rule has a control that MUST fail, and fails through the same
## function the case uses, not a copy of it:
##
##   road    a through road laid straight up plane_30's fall line (30 % > 12 %)
##   fall    a house asked for one metre more fall than its family takes
##   walk    the same Manarola bake with its access flights removed: doors
##           are stranded (VillageStepsWalkSuite._without_access)
##   wet     a lot in lake_shore's southern quarter, below the water level
##   cliff   a lot laid across cliff_band's 15 m step
##   siting  a frame that turns the site's corners off a grid that only just
##           covers it; and the fall-line frame scores worse than the contour
##           frame on plane_30
##
## Run: godot --headless --path . --script res://tests/run_all.gd -- lane:village-terrain
## The much fuller suites stay where they were: `vtplan` (every form and
## fixture, ~5 min), `vstepswalk` (two stair villages, ~5.5 min loaded),
## `vterrain`, `vanalysis`.

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const REAL30 := "res://tests/fixtures/terrain/real30/"
const EXPORTER := preload("res://tools/export_village_plan.gd")
const STEPS := preload("res://tests/suites/village_steps_walk_suite.gd")
const POPULATION := 30
const SEED := 4242
const CARRIED_TOL := 0.01
const ARRIVE := 0.05
## the ground's own cell on every fixture this lane uses
const EPS := 1e-6

## [fixture, form, the rule the case is here for]
const CASES := [
	["plane_30", &"street", "30 % plane: grades, contour siting, fall"],
	["lake_shore", &"green", "wet ground at its water level"],
	["cliff_band", &"gate", "a 15 m step"],
	["real30/manarola", &"crossroads", "real: a stair street, access flights"],
	["real30/masouleh", &"street", "real: a 40-60 % hillside"],
	["real30/monpazier", &"green", "real: a gentle bastide"],
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("vterrainlane")
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(spec_for(&"street", null)))
	res.note("measured %d buildings once in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for case in CASES:
		_case(res, jobs, case[0], case[1], case[2])
	_controls(res, jobs)
	_refusals(res, jobs)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func spec_for(form: StringName, ground: VillageTerrain) -> VillageSpec:
	var s := VillageSpec.new(SEED)
	s.population = POPULATION
	s.generate(SEED)
	s.form = form
	s.terrain = ground
	return s


static func terrain(name: String) -> VillageTerrain:
	if name.begins_with("real30/"):
		return VillageTerrain.from_file(REAL30 + name.substr(7) + ".json")
	return SYNTH.make(name)


static func _case(res: SuiteResult, jobs: Array[Dictionary], name: String, form: StringName,
		why: String) -> void:
	var label := "%s/%s" % [name, form]
	var ground := terrain(name)
	res.checked += 1
	if ground == null or not ground.valid():
		res.fail("%s: the fixture does not read" % label)
		return
	var t0 := Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(spec_for(form, ground), jobs)
	var plan_s := (Time.get_ticks_msec() - t0) / 1000.0
	res.checked += 1
	if plan.ground == null or plan.ground.parent != ground or plan.roads.is_empty():
		res.fail("%s: the plan was not sited on its ground" % label)
		return
	_sited(res, ground, plan, label)
	_estimate_spares(res, plan, label)
	_grades(res, ground, plan, label)
	_dry(res, plan, label)
	_falls(res, plan, label)
	var worst := _worst_grades(plan)
	var fits := 0
	var most_fall := 0.0
	for b in plan.buildings:
		var fit: Dictionary = plan.lots[int(b["lot"])].get("ground_fit", {})
		if fit.is_empty():
			continue
		fits += 1
		most_fall = maxf(most_fall, float(fit.get("fall_m", 0.0)))
	res.note("%-22s plan %.1f s | anchor (%.0f, %.0f) yaw %.1f site %.0fx%.0f | %d buildings, %d on platforms, most fall %.2f m | grades%s | %s" % [
		label, plan_s, plan.site_anchor.x, plan.site_anchor.y, rad_to_deg(plan.site_yaw),
		plan.site.size.x, plan.site.size.y, plan.buildings.size(), fits, most_fall, worst, why])
	if name == "real30/manarola" and form == &"crossroads":
		_walk(res, plan, label)


## (e) the siting rules: where it stands, that it is on the grid, that the
## frame view reads the caller's ground, and that the common is level and dry.
static func _sited(res: SuiteResult, ground: VillageTerrain, plan: VillagePlan, label: String) -> void:
	res.checked += 1
	if not EXPORTER.covers_plan(ground, plan):
		res.fail("%s: the sited site's corners leave the grid" % label)
	res.checked += 1
	if plan.site_yaw < -EPS or plan.site_yaw >= TAU + EPS:
		res.fail("%s: the yaw %.3f is not an angle" % [label, plan.site_yaw])
	res.checked += 1
	if Vector2(plan.site_anchor).length() > VillageSiting.REACH_M + EPS:
		res.fail("%s: the anchor stands %.0f m from the caller's centre" % [
			label, Vector2(plan.site_anchor).length()])
	# the frame view is the caller's ground where the village stands
	res.checked += 1
	var probe := plan.site.get_center() + Vector2(7.0, -3.0)
	var framed: float = plan.ground.height_at(probe)
	var given: float = ground.height_at(plan.ground.to_parent(probe))
	if absf(framed - given) > 0.05 * maxf(1.0, ground.cell_m):
		res.fail("%s: the frame view reads %.2f m where the caller's ground is %.2f m" % [label, framed, given])
	if plan.commons.is_empty():
		return
	var common: PackedVector2Array = plan.commons[0]["poly"]
	# every plan point is in the village frame; the reading is the frame view's
	var u := plan.ground.under(common)
	res.checked += 1
	if float(u["dry_share"]) < 1.0:
		res.fail("%s: the common is on standing water (dry share %.2f)" % [label, float(u["dry_share"])])
	var slopes: Array[float] = []
	for lot in plan.lots:
		slopes.append(float(plan.ground.under(lot["poly"])["slope_mean"]))
	slopes.sort()
	var median := slopes[slopes.size() / 2] if not slopes.is_empty() else 0.0
	var allow := maxf(0.08, median + VillagePlaceCheck.COMMON_SLOPE_SLACK)
	res.checked += 1
	if float(u["slope_mean"]) > allow + EPS:
		res.fail("%s: the common lies on %.1f %% though the village's median lot is %.1f %% (allowed %.1f %%)" % [
			label, float(u["slope_mean"]) * 100.0, median * 100.0, allow * 100.0])


## (a) every road within its class's cap, on the plan's own ground and on the
## caller's grid at the carried points.
static func _grades(res: SuiteResult, ground: VillageTerrain, plan: VillagePlan, label: String) -> void:
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var cls: StringName = road["class"]
		var pts: PackedVector2Array = road["points"]
		var cap: float = float(VillageSitePlanner.ROAD_CLASSES[cls]["grade_max"])
		var msg := _grade_problem(plan.ground, cls, pts)
		res.checked += 1
		if msg != "":
			res.fail("%s: %s %d: %s" % [label, cls, r, msg])
		var carried := PackedVector2Array()
		for p in pts:
			carried.append(plan.ground.to_parent(p))
		var on_given: float = float(ground.profile(carried)["grade_max"])
		res.checked += 1
		if on_given > cap + CARRIED_TOL:
			res.fail("%s: %s %d climbs %.1f %% on the caller's grid, its class is laid to %.0f %%" % [
				label, cls, r, on_given * 100.0, cap * 100.0])


## (d) nothing on wet ground: no lot, building, common or road end.
static func _dry(res: SuiteResult, plan: VillagePlan, label: String) -> void:
	for i in plan.lots.size():
		res.checked += 1
		var why := _lot_problem(plan.ground, plan.lots[i], label, i)
		if why != "":
			res.fail(why)
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		var rect := Placement.world_rect(b["placement"], b["transform"], true)
		var u := plan.ground.under(rect)
		res.checked += 1
		if float(u["dry_share"]) < 1.0:
			res.fail("%s: building %d stands in standing water (dry share %.2f)" % [
				label, i, float(u["dry_share"])])
	for w in plan.water:
		if w["kind"] == &"race":
			continue
		for r in plan.roads.size():
			var pts: PackedVector2Array = plan.roads[r]["points"]
			res.checked += 1
			for p in [pts[0], pts[pts.size() - 1]]:
				if Poly.contains_point(w["poly"], p):
					res.fail("%s: %s %d ends in the %s" % [label, plan.roads[r]["class"], r, w["kind"]])


## The lot rule shared by the cases and the cliff/wet controls. Empty when
## the lot is clear ground; else why it is not.
static func _lot_problem(ground: VillageTerrain, lot: Dictionary, label: String, i := -1) -> String:
	var poly: PackedVector2Array = lot["poly"]
	var u := ground.under(poly)
	var where: String = ("%s: lot %d" % [label, i]) if i >= 0 else label
	if float(u["dry_share"]) < 1.0:
		return "%s stands on standing water (dry share %.2f)" % [where, float(u["dry_share"])]
	var cliffs: bool = not bool(lot.get("terraced", false))
	if not VillageLotPlanner.ground_clear(ground, poly, cliffs):
		return "%s crosses a cliff band (%.1f m of fall under it)" % [where, float(u["span_m"])]
	return ""


## (b) the fall against what the family can stand on.
static func _falls(res: SuiteResult, plan: VillagePlan, label: String) -> void:
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		var req: BuildingRequest = b["request"]
		var lot: Dictionary = plan.lots[int(b["lot"])]
		res.checked += 1
		if not lot.has("ground_fit"):
			res.fail("%s: building %d's lot has no platform on given ground" % [label, i])
			continue
		var fit: Dictionary = lot["ground_fit"]
		var limit := VillageLotGround.fall_limit(req)
		var want: float = float(fit["fall_m"]) if limit > 0.0 else 0.0
		res.checked += 1
		if absf(req.ground_fall_m - want) > EPS:
			res.fail("%s: building %d asks for %.2f m of fall, its lot says %.2f m" % [
				label, i, req.ground_fall_m, want])
		res.checked += 1
		if limit > 0.0 and req.ground_fall_m > limit + EPS:
			res.fail("%s: building %d (%s) stands on %.2f m of fall, its family takes %.2f m in a village" % [
				label, i, req.kind, req.ground_fall_m, limit])
		res.checked += 1
		var errs := BuildingLibrary.validate(req)
		if not errs.is_empty():
			res.fail("%s: building %d's request is refused: %s" % [
				label, i, String(errs[0].get("message", errs[0]))])


## (c) the walk with stairs: the same core vstepswalk measures, bounded to one
## village. Every stair street is stepped, every lot has a way in, and
## NavigationServer3D walks from the first gate to every door over the baked
## 3D mesh and its links.
static func _walk(res: SuiteResult, plan: VillagePlan, label: String) -> void:
	var surface := VillageGroundSurface.of(plan)
	var stair_streets := 0
	var treads := 0
	for i in plan.roads.size():
		var bed: Dictionary = surface.road_bed(i)
		if plan.roads[i]["class"] == &"steps" and bed.has("treads"):
			stair_streets += 1
			treads += (bed["treads"] as Array).size()
	var access := 0
	for lot in plan.lots:
		var a: Dictionary = lot.get("ground_fit", {}).get("access", {})
		if a.has("treads"):
			access += 1
	res.checked += 1
	if stair_streets < 1 or treads < 1:
		res.fail("%s: no stair street with treads (%d streets, %d treads)" % [label, stair_streets, treads])
	res.checked += 1
	if access < 1:
		res.fail("%s: no lot has a way in on its step" % label)
	var t0 := Time.get_ticks_msec()
	var walk: Dictionary = VillageWalk.projection(plan, "lane")
	var walk_s := (Time.get_ticks_msec() - t0) / 1000.0
	res.checked += 1
	var nav: Dictionary = walk.get("navmesh_3d", {})
	if nav.is_empty() or (nav.get("polygons", []) as Array).is_empty():
		res.fail("%s: no 3D navigation mesh" % label)
		return
	var m3 := _mesh(nav)
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, VillageWalk3D.CELL)
	NavigationServer3D.map_set_cell_height(map, VillageWalk3D.CELL_HEIGHT)
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, float(nav["merge_rasterizer_cell_scale"]))
	NavigationServer3D.map_set_use_async_iterations(map, false)
	NavigationServer3D.map_set_active(map, true)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_use_async_iterations(region, false)
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, VillageWalk3D.to_navigation_mesh(m3))
	var links: Array[RID] = []
	for link in m3["links"]:
		var rid := NavigationServer3D.link_create()
		NavigationServer3D.link_set_map(rid, map)
		NavigationServer3D.link_set_bidirectional(rid, true)
		NavigationServer3D.link_set_start_position(rid, link["from"])
		NavigationServer3D.link_set_end_position(rid, link["to"])
		links.append(rid)
	NavigationServer3D.map_force_update(map)
	res.checked += 1
	if (walk.get("gates", []) as Array).is_empty() or walk["gates"][0].get("nav_3d_m") == null:
		res.fail("%s: the first gate is not on the 3D mesh" % label)
		for rid in links:
			NavigationServer3D.free_rid(rid)
		NavigationServer3D.free_rid(region)
		NavigationServer3D.free_rid(map)
		return
	res.checked += 1
	if (walk.get("doors", []) as Array).is_empty():
		res.fail("%s: the walk has no doors to reach" % label)
	var from := _v3(walk["gates"][0]["nav_3d_m"])
	var arrived := 0
	var failed: Array[String] = []
	var climbed := 0.0
	for d in walk["doors"]:
		res.checked += 1
		if d["outside_3d_m"] == null:
			failed.append("%s (no 3D point)" % d["building_id"])
			continue
		var to := _v3(d["outside_3d_m"])
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		if path.is_empty() or path[path.size() - 1].distance_to(to) > ARRIVE:
			failed.append("%s" % d["building_id"])
			continue
		arrived += 1
		var lo := INF
		var hi := -INF
		for p in path:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		climbed = maxf(climbed, hi - lo)
	for rid in links:
		NavigationServer3D.free_rid(rid)
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	res.checked += 1
	if not failed.is_empty():
		res.fail("%s: NavigationServer3D reached %d of %d doors; %s" % [
			label, arrived, walk["doors"].size(), ", ".join(failed.slice(0, 6))])
	# the control: without the access flights, the same bake strands doors
	var control := STEPS._without_access(plan)
	res.checked += 1
	if access > 0 and control <= 0:
		res.fail("%s: control -- without its %d access flights no door was stranded; the walk check sees nothing" % [
			label, access])
	res.note("%s walk: %d stair streets (%d treads), %d access flights, %d entry flights; navmesh %d vertices / %d polygons; doors reached %d/%d, climbed up to %.1f m; projection %.1f s; control: %d doors stranded without access flights" % [
		label, stair_streets, treads, access, _entry_flights(plan), (m3["vertices"] as PackedVector3Array).size(),
		(m3["polygons"] as Array).size(), arrived, walk["doors"].size(), climbed, walk_s, control])


static func _entry_flights(plan: VillagePlan) -> int:
	var n := 0
	for lot in plan.lots:
		n += (lot.get("ground_fit", {}).get("entry_flights", []) as Array).size()
	return n


## JSON's [[x, y, z]] and polygons back into the shape VillageWalk3D returns.
static func _mesh(data: Dictionary) -> Dictionary:
	var verts := PackedVector3Array()
	for v in data["vertices_m"]:
		verts.append(_v3(v))
	var polygons: Array[PackedInt32Array] = []
	for p in data["polygons"]:
		polygons.append(PackedInt32Array(p))
	var links: Array = []
	for l in data.get("links", []):
		links.append({"from": _v3(l["from_m"]), "to": _v3(l["to_m"])})
	return {"vertices": verts, "polygons": polygons, "links": links}


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## One failing control per rule, each through the function the cases use.
## (f) BG-012-EARLY-REFUSE. The capacity estimate must never refuse a case that
## fits: every fixture above planned, so none may carry a capacity stop. The
## failing controls are `_refusals`: ground that cannot hold the programme.
static func _estimate_spares(res: SuiteResult, plan: VillagePlan, label: String) -> void:
	var capacity: Dictionary = plan.search.get("capacity", {})
	res.checked += 1
	if plan.search.is_empty() or capacity.is_empty():
		res.fail("%s: the plan carries no capacity estimate" % label)
	elif bool(capacity["refuse"]) or String(plan.search["stopped"]) != "":
		res.fail("%s: the estimate refused ground that planned (%s, stopped %s)" % [
			label, capacity["reason"], plan.search["stopped"]])


## A hump 8 m across in a drowned plain, and a wall (100 %) with no level ground.
static func _hopeless(name: String) -> VillageTerrain:
	var rect := Rect2(-400, -400, 800, 800)
	if name == "drowned":
		return VillageTerrain.from_sampler(func(x: float, z: float) -> float:
			return 10.0 if Vector2(x, z).length() < 8.0 else 0.0, rect, 5.0, 5.0)
	return VillageTerrain.from_sampler(func(_x: float, z: float) -> float: return z, rect, 5.0)


static func _refusals(res: SuiteResult, jobs: Array[Dictionary]) -> void:
	var programme: Array[BuildingRequest] = []
	for job in jobs:
		programme.append(job["request"])
	for name in ["drowned", "wall"]:
		var t0 := Time.get_ticks_msec()
		var plan := VillageLotPlanner.plan_measured(spec_for(&"street", _hopeless(name)), jobs)
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		var cap: Dictionary = plan.search.get("capacity", {})
		res.checked += 4
		if String(plan.search.get("stopped", "")) != "capacity" or not bool(cap.get("refuse", false)):
			res.fail("refuse %s: the estimate let hopeless ground through (%s)" % [name, plan.search])
			continue
		if int(plan.search["attempts"]) != 0:
			res.fail("refuse %s: the ladder ran %d re-plans after an early refusal" % [name, plan.search["attempts"]])
		var rule := "wet" if name == "drowned" else "cliff"
		var named := {}
		for r in cap["rules"]:
			named[r["rule"]] = float(r["share"])
		if float(named.get(rule, 0.0)) < 0.9:
			res.fail("refuse %s: the breakdown does not name %s as most of the ground: %s" % [name, rule, cap["rules"]])
		var block := EXPORTER.refusal(plan, programme, programme.size())
		if String(block["reason"]).find(rule) < 0 or String(block["stopped"]) != "capacity" 				or (block["unplaced"] as Array).size() != programme.size() - plan.buildings.size():
			res.fail("refuse %s: the refusal block is incomplete: %s" % [name, block])
		res.note("refuse %-7s %.1f s, stopped %s | %s" % [name, secs, plan.search["stopped"], block["reason"]])
	# the budget: the programme with its households three times over does not fit
	# cliff_band at all (28 of 30 after all fifteen re-plans, 38 s); one re-plan,
	# or a millisecond, is not enough either, and the plan so far comes back
	var crowd: Array[Dictionary] = []
	for again in range(4):
		for job in jobs:
			if again > 0 and not (job["class"] in [&"cottage", &"farm", &"townhouse"]):
				continue
			var copy := job.duplicate()
			copy["order"] = crowd.size()
			crowd.append(copy)
	for budget in [{"attempts": 1}, {"seconds": 0.001}]:
		var spec := spec_for(&"gate", SYNTH.make("cliff_band"))
		spec.search_max_attempts = int(budget.get("attempts", 0))
		spec.search_budget_s = float(budget.get("seconds", 0.0))
		var t1 := Time.get_ticks_msec()
		var plan := VillageLotPlanner.plan_measured(spec, crowd)
		var want := "budget_attempts" if budget.has("attempts") else "budget_time"
		res.checked += 3
		if String(plan.search.get("stopped", "")) != want:
			res.fail("budget %s: stopped '%s'" % [budget, plan.search.get("stopped", "")])
		if plan.buildings.is_empty() or plan.buildings.size() >= crowd.size():
			res.fail("budget %s: %d of %d placed, a partial plan wants some but not all" % [
				budget, plan.buildings.size(), crowd.size()])
		if budget.has("attempts") and int(plan.search["attempts"]) != 1:
			res.fail("budget %s: %d re-plans" % [budget, plan.search["attempts"]])
		res.note("budget %s: %d of %d placed in %.1f s, %d re-plans" % [budget, plan.buildings.size(),
			crowd.size(), (Time.get_ticks_msec() - t1) / 1000.0, plan.search["attempts"]])


static func _controls(res: SuiteResult, jobs: Array[Dictionary]) -> void:
	# (a) a through road laid up plane_30's fall line: 30 % against a cart's 12 %
	var plane := SYNTH.make("plane_30")
	var up := PackedVector2Array([Vector2(0.0, -40.0), Vector2(0.0, 40.0)])
	var across := PackedVector2Array([Vector2(-40.0, 20.0), Vector2(40.0, 20.0)])
	var road_msg := _grade_problem(plane, &"through", up)
	res.checked += 1
	if road_msg == "":
		res.fail("control road: a 30 %% through road on plane_30 was not reported")
	var flat_msg := _grade_problem(plane, &"through", across)
	res.checked += 1
	if flat_msg != "":
		res.fail("control road: a contour through road was reported: %s" % flat_msg)
	res.note("control road (must fail): a through road up the fall line -> %s" % road_msg)
	# (b) a house asked for more fall than its family takes
	var house: BuildingRequest = null
	for job in jobs:
		var req: BuildingRequest = job["request"]
		if req.kind in [&"house", &"shop"]:
			house = req
			break
	if house == null:
		res.fail("control fall: no house in the programme to ask about")
	else:
		var limit := VillageLotGround.fall_limit(house)
		var over := _reading_for(house, limit + 1.0)
		var at := _reading_for(house, maxf(0.0, limit - 0.25))
		var fall_msg := VillageLotGround.refusal(house, over)
		var fall_ok := VillageLotGround.refusal(house, at)
		res.checked += 1
		if limit <= 0.0 or fall_msg == "":
			res.fail("control fall: a %.2f m fall for a %s (limit %.2f m) was accepted" % [limit + 1.0, house.kind, limit])
		res.checked += 1
		if fall_ok != "":
			res.fail("control fall: a %.2f m fall for a %s (limit %.2f m) was refused: %s" % [
				maxf(0.0, limit - 0.25), house.kind, limit, fall_ok])
		res.note("control fall (must fail): a %s on %.2f m, limit %.2f m -> %s" % [
			house.kind, limit + 1.0, limit, fall_msg])
	# (d) a lot in lake_shore's southern quarter, below the water level
	var shore := SYNTH.make("lake_shore")
	var wet_lot := {"poly": Poly.from_rect(Rect2(-10.0, 210.0, 20.0, 20.0)), "terraced": false}
	var dry_lot := {"poly": Poly.from_rect(Rect2(-10.0, 0.0, 20.0, 20.0)), "terraced": false}
	var wet_msg := _lot_problem(shore, wet_lot, "control wet lot")
	var dry_msg := _lot_problem(shore, dry_lot, "control dry lot")
	res.checked += 1
	if wet_msg == "":
		res.fail("control wet: a lot below lake_shore's water level was not reported")
	res.checked += 1
	if dry_msg != "":
		res.fail("control wet: a dry lot on lake_shore was reported: %s" % dry_msg)
	res.note("control wet (must fail): %s" % wet_msg)
	# the cliff band: a lot laid across its 15 m step, and one beside it
	var cliff := SYNTH.make("cliff_band")
	var cliff_lot := {"poly": Poly.from_rect(Rect2(-10.0, 46.0, 20.0, 8.0)), "terraced": false}
	var safe_lot := {"poly": Poly.from_rect(Rect2(-10.0, 10.0, 20.0, 20.0)), "terraced": false}
	var cliff_msg := _lot_problem(cliff, cliff_lot, "control cliff lot")
	var safe_msg := _lot_problem(cliff, safe_lot, "control flat lot")
	res.checked += 1
	if cliff_msg == "":
		res.fail("control cliff: a lot across cliff_band's 15 m step was not reported")
	res.checked += 1
	if safe_msg != "":
		res.fail("control cliff: a flat lot on cliff_band was reported: %s" % safe_msg)
	res.note("control cliff (must fail): %s" % cliff_msg)
	# (e) a grid that only just covers the site: the caller's centre is kept,
	# and a yaw that turns the corners off the grid is refused
	var spec := spec_for(&"street", plane)
	var flat := VillageSitePlanner.plan_flat(spec)
	var half: float = maxf(flat.site.size.x, flat.site.size.y) * 0.5 + 1.0
	var tight := SYNTH.make("plane_30", Rect2(-half, -half, 2.0 * half, 2.0 * half), 5.0)
	var sited := VillageSiting.choose(tight, flat, false)
	res.checked += 1
	if not bool(sited["fixed_centre"]) or Vector2(sited["anchor"]).length() > EPS:
		res.fail("control siting: a grid that only just covers the site moved its centre to %s" % sited["anchor"])
	res.checked += 1
	if not VillageSiting._covered(tight.bounds(), flat.site, Vector2.ZERO, 0.0):
		res.fail("control siting: the axis-aligned frame does not fit the tight grid")
	res.checked += 1
	if VillageSiting._covered(tight.bounds(), flat.site, Vector2.ZERO, PI / 4.0):
		res.fail("control siting: a 45-degree frame's corners were accepted off the tight grid")
	# the road term must prefer the contour frame to the fall line
	var samples := VillageSiting._samples(flat)
	var contour := VillageSiting._score(plane, samples, Vector2.ZERO, 0.0, PackedVector2Array(), false)
	var fall_line := VillageSiting._score(plane, samples, Vector2.ZERO, PI / 2.0, PackedVector2Array(), false)
	var contour_road := float((contour["terms"] as Dictionary)["road"])
	var fall_road := float((fall_line["terms"] as Dictionary)["road"])
	res.checked += 1
	if not (fall_road > contour_road + 1.0):
		res.fail("control siting: the fall-line frame's road term %.2f is not worse than the contour frame's %.2f" % [
			fall_road, contour_road])
	res.note("control siting (must fail): a 45-degree frame leaves the tight grid; road term contour %.2f vs fall line %.2f" % [
		contour_road, fall_road])


static func _grade_problem(ground: VillageTerrain, cls: StringName, pts: PackedVector2Array) -> String:
	var cap: float = float(VillageSitePlanner.ROAD_CLASSES[cls]["grade_max"])
	var g: float = float(ground.profile(pts)["grade_max"])
	if g > cap + EPS:
		return "%s climbs %.1f %%, its class is laid to %.0f %%" % [cls, g * 100.0, cap * 100.0]
	return ""


## A reading with exactly this fall, for the fall-capability control.
static func _reading_for(request: BuildingRequest, fall: float) -> Dictionary:
	return {"fall_m": fall, "width": request.width, "length": request.length,
		"downhill_deg": 0.0, "cut_m": 0.0, "fill_m": 0.0}


static func _worst_grades(plan: VillagePlan) -> String:
	var worst := {}
	for r in plan.roads.size():
		var road: Dictionary = plan.roads[r]
		var cls: StringName = road["class"]
		worst[cls] = maxf(float(worst.get(cls, 0.0)), float(plan.ground.profile(road["points"])["grade_max"]))
	var out := ""
	var keys := worst.keys()
	keys.sort()
	for cls in keys:
		out += " %s %.1f%%" % [cls, float(worst[cls]) * 100.0]
	return out
