extends RefCounted
## A caller that shapes its own ground (CITY-GROUND-CONTRACT,
## docs/VILLAGE_TERRAIN.md "The caller shapes the ground"): the exporter's
## `--ground-policy shape`.
##
##   easing scales the DRY relief about its mean and moves neither the water,
##   the shore nor the grid's edge; the lift is exactly eased minus given
##   the ladder of grounds is read from the caller, or refused
##   a hamlet that a wall of ground refuses outright stands WHOLE once the
##   ground is eased, and the plan says which ground it stands on
##   the finished ground is the built ground inside the site (every lot on its
##   platform) and the given ground round it, in the plan's frame
##   the earthworks are written where a consumer reads them back unchanged
##   without the policy the one plan made is the plan on the ground as given

const EXPORTER := preload("res://tools/export_village_plan.gd")
const HAMLET := "res://tests/fixtures/site_requests/thorn-hamlet.json"
const EPS := 1e-4


static func run() -> SuiteResult:
	var res := SuiteResult.new("vgroundshape")
	_easing(res)
	_ladder(res)
	_whole_programme(res)
	return res


## A hill 40 m high over a lake at 5 m, 400 m square at 5 m.
static func _hill() -> VillageTerrain:
	return VillageTerrain.from_sampler(func(x: float, z: float) -> float:
		return maxf(0.0, 40.0 - 0.2 * Vector2(x, z).length()), Rect2(-200, -200, 400, 400), 5.0, 5.0)


static func _easing(res: SuiteResult) -> void:
	var given := _hill()
	# the ground as given is the ground itself, and moves nothing
	var whole: Dictionary = VillageGroundEasing.eased(given, 1.0)
	res.checked += 1
	if whole["terrain"] != given or float(whole["cut_max_m"]) != 0.0 or float(whole["fill_max_m"]) != 0.0:
		res.fail("easing: keep 1 is not the given ground untouched")
	for keep in [0.5, 0.25, 0.0]:
		var got: Dictionary = VillageGroundEasing.eased(given, keep)
		var eased: VillageTerrain = got["terrain"]
		var label := "easing %s" % String.num(keep, 2)
		res.checked += 6
		if not eased.valid() or eased.cols != given.cols or eased.rows != given.rows \
				or not eased.origin.is_equal_approx(given.origin) or eased.water_level_m != given.water_level_m:
			res.fail("%s: the eased ground is not on the given lattice" % label)
			continue
		var datum: float = float(got["datum_m"])
		var moved_wet := 0
		var moved_edge := 0
		var off := 0.0
		var steeper := 0
		for r in range(given.rows):
			for c in range(given.cols):
				var i: int = r * given.cols + c
				var h: float = given.heights[i]
				var g: float = eased.heights[i]
				if h <= given.water_level_m and absf(g - h) > EPS:
					moved_wet += 1
				if (r == 0 or c == 0 or r == given.rows - 1 or c == given.cols - 1) and absf(g - h) > EPS:
					moved_edge += 1
				# never farther from the datum than it was
				if absf(g - datum) > absf(h - datum) + EPS:
					steeper += 1
				# dry and well inside the band: exactly the scaled height
				var p := given.origin + Vector2(c, r) * given.cell_m
				if h > given.water_level_m + VillageGroundEasing.SHORE_BAND_M \
						and absf(p.x) < 200.0 - float(got["band_m"]) and absf(p.y) < 200.0 - float(got["band_m"]):
					off = maxf(off, absf(g - (datum + keep * (h - datum))))
		if moved_wet > 0:
			res.fail("%s: %d nodes at or under the water moved" % [label, moved_wet])
		if moved_edge > 0:
			res.fail("%s: %d nodes on the grid's edge moved" % [label, moved_edge])
		if steeper > 0:
			res.fail("%s: %d nodes stand farther from the datum than they did" % [label, steeper])
		if off > 1e-3:
			res.fail("%s: the dry middle is %.4f m off datum + keep x (given - datum)" % [label, off])
		# the lift is what a caller adds: given + lift == eased, node for node
		var lift: VillageTerrain = VillageGroundEasing.lift(given, eased)
		var worst := 0.0
		for i in range(lift.heights.size()):
			worst = maxf(worst, absf(given.heights[i] + lift.heights[i] - eased.heights[i]))
		if worst > 1e-4 or not is_nan(lift.water_level_m):
			res.fail("%s: given + lift is %.5f m off the eased ground" % [label, worst])
		res.checked += 2
		if float(got["cut_max_m"]) <= 0.0 or float(got["fill_max_m"]) <= 0.0 or float(got["changed_share"]) <= 0.0:
			res.fail("%s: easing a hill reports no cut or no fill: %s" % [label, got])
		if eased.relief() > given.relief() + EPS:
			res.fail("%s: relief grew from %.1f to %.1f m" % [label, given.relief(), eased.relief()])
		res.note("%s: datum %.1f m, cut to %.1f, fill to %.1f, %.0f %% of the grid moved" % [label, datum,
			float(got["cut_max_m"]), float(got["fill_max_m"]), 100.0 * float(got["changed_share"])])
	# the same ground eased twice is the same ground
	res.checked += 1
	if (VillageGroundEasing.eased(given, 0.5)["terrain"] as VillageTerrain).fingerprint() \
			!= (VillageGroundEasing.eased(_hill(), 0.5)["terrain"] as VillageTerrain).fingerprint():
		res.fail("easing: two easings of one ground differ")
	# ground with no water eases about its mean everywhere inside the band
	var dry := VillageTerrain.from_sampler(func(x: float, _z: float) -> float: return 0.3 * x, Rect2(-200, -200, 400, 400), 5.0)
	var level: Dictionary = VillageGroundEasing.eased(dry, 0.0)
	res.checked += 1
	if absf((level["terrain"] as VillageTerrain).height_at(Vector2(60.0, -40.0)) - float(level["datum_m"])) > 1e-3:
		res.fail("easing: keep 0 on dry ground is not level at the datum in the middle")


static func _ladder(res: SuiteResult) -> void:
	var cases := [
		[EXPORTER.GROUND_KEEP, "", [1.0]],
		[EXPORTER.GROUND_KEEP, "0.5,0", [1.0]],          # the list means nothing without the policy
		[EXPORTER.GROUND_SHAPE, "", VillageGroundEasing.LADDER],
		[EXPORTER.GROUND_SHAPE, "1, 0.5,0", [1.0, 0.5, 0.0]],
		[EXPORTER.GROUND_SHAPE, "0.25", [0.25]],
		[EXPORTER.GROUND_SHAPE, "0.5,1", []],             # not from most relief to least
		[EXPORTER.GROUND_SHAPE, "1,1.5", []],
		[EXPORTER.GROUND_SHAPE, "1,half", []],
		["level", "", []],
	]
	for row in cases:
		var got: Array[float] = EXPORTER.keep_ladder(String(row[0]), String(row[1]))
		var want: Array = row[2]
		res.checked += 1
		var same: bool = got.size() == want.size()
		for i in range(mini(got.size(), want.size())):
			same = same and is_equal_approx(got[i], float(want[i]))
		if not same:
			res.fail("ladder: policy '%s' with '%s' gives %s, wanted %s" % [row[0], row[1], got, want])
	res.checked += 1
	if VillageGroundEasing.LADDER.is_empty() or VillageGroundEasing.LADDER[0] != 1.0 or VillageGroundEasing.LADDER[-1] != 0.0:
		res.fail("ladder: the default must start at the ground as given and end level")


## The hamlet's request as the exporter reads it, without a seat (a council's
## hamlet: no castle to measure on every fall, so the suite stays minutes).
static func _request() -> Array:
	var text: String = FileAccess.get_file_as_string(HAMLET)
	var parsed: Dictionary = JSON.parse_string(text)
	parsed["regime"] = "council"
	var notes: Array[String] = []
	var request: Dictionary = EXPORTER.with_implied_population(EXPORTER.with_caller_population(parsed, "", notes), "")
	return [request, text, notes]


static func _whole_programme(res: SuiteResult) -> void:
	var made: Array = _request()
	var request: Dictionary = made[0]
	var text: String = made[1]
	var notes: Array[String] = made[2]
	# a wall: the ground rises a metre a metre. Nothing stands on it.
	var wall := VillageTerrain.from_sampler(func(_x: float, z: float) -> float: return z, Rect2(-400, -400, 800, 800), 5.0)
	var cache := VillageMeasureCache.new()
	var t0 := Time.get_ticks_msec()
	# without the policy: one plan, on the ground as given, and it is short
	var kept: Dictionary = EXPORTER.plan_shaped(request, text, {}, wall,
		EXPORTER.keep_ladder(EXPORTER.GROUND_KEEP, ""), {}, notes, cache)
	res.checked += 3
	var kept_tried: Array = kept["tried"]
	if kept_tried.size() != 1 or float(kept_tried[0]["keep_relief"]) != 1.0:
		res.fail("keep: the ground as given was not the one ground tried: %s" % [kept_tried])
		return
	if int(kept_tried[0]["placed"]) >= int(kept_tried[0]["requested"]):
		res.fail("keep: a hamlet stood whole on a wall of ground (%s); the control is no control" % [kept_tried])
		return
	if (kept["got"] as Dictionary).is_empty() or float(kept["got"]["eased"]["keep"]) != 1.0:
		res.fail("keep: the partial plan was not kept with its ground")
	# with it: the same request on the same ground, eased until all of it stands
	var ladder: Array[float] = EXPORTER.keep_ladder(EXPORTER.GROUND_SHAPE, "1,0.1,0")
	var shaped: Dictionary = EXPORTER.plan_shaped(request, text, {}, wall, ladder, {}, notes, cache)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var tried: Array = shaped["tried"]
	var got: Dictionary = shaped["got"]
	res.checked += 4
	if got.is_empty():
		res.fail("shape: nothing was planned (%s)" % shaped["failed"])
		return
	var plan: VillagePlan = got["plan"]
	var programme: Array = got["programme"]
	if plan.buildings.size() < programme.size():
		res.fail("shape: %d of %d buildings stand after every ground was tried: %s" % [
			plan.buildings.size(), programme.size(), tried])
		return
	if tried.size() < 2 or float(tried[0]["keep_relief"]) != 1.0 \
			or int(tried[0]["placed"]) >= int(tried[0]["requested"]):
		res.fail("shape: the ground as given was not tried first, or held the hamlet: %s" % [tried])
	var keep: float = float(got["eased"]["keep"])
	if keep >= 1.0 or float(tried[-1]["keep_relief"]) != keep or int(tried[-1]["placed"]) != programme.size():
		res.fail("shape: the plan kept is not the last ground tried (keep %s, tried %s)" % [keep, tried])
	if plan.ground == null or plan.ground.parent != got["eased"]["terrain"]:
		res.fail("shape: the plan is not sited on the eased ground")
		return
	res.note("whole programme: %d buildings on a wall of ground, %s; kept %s of the relief, %.0f s" % [
		programme.size(), tried, String.num(keep, 2), secs])
	_finished(res, plan)
	_written(res, plan, wall, got["eased"], tried)


## The finished ground of a plan: the built ground inside the site, the given
## ground round it.
static func _finished(res: SuiteResult, plan: VillagePlan) -> void:
	var finished: VillageTerrain = VillageFinishedGround.grid(plan)
	res.checked += 5
	if finished == null or not finished.valid():
		res.fail("finished: no grid for a plan on its ground")
		return
	if not finished.covers(plan.site.grow(VillageFinishedGround.MARGIN_M - 0.01)):
		res.fail("finished: the grid %s does not cover the site and its margin %s" % [finished.bounds(), plan.site])
	var surface := VillageGroundSurface.of(plan)
	# every building's lot is on its platform: the floor's level under the
	# building's own origin, where GroundFall's plane is the platform itself
	# or below it, never above
	var worst_pad := 0.0
	var over := 0
	for b in plan.buildings:
		var lot: Dictionary = plan.lots[int(b["lot"])]
		if not lot.has("ground_fit"):
			continue
		var xf: Transform3D = b["transform"]
		var at := Vector2(xf.origin.x, xf.origin.z)
		var platform: float = float(lot["ground_fit"]["platform_m"])
		var here: float = finished.height_at(at)
		worst_pad = maxf(worst_pad, absf(here - surface.height_at(at)))
		if here > platform + 0.05:
			over += 1
	if worst_pad > 0.35:
		res.fail("finished: the grid is %.2f m off the built ground under a building" % worst_pad)
	if over > 0:
		res.fail("finished: the ground stands above the floor under %d buildings" % over)
	# round the site the grid is the ground the plan was made on
	var worst_margin := 0.0
	var outside: Rect2 = plan.site.grow(VillageFinishedGround.MARGIN_M * 0.5)
	for corner in [outside.position, outside.end, Vector2(outside.position.x, outside.end.y),
			Vector2(outside.end.x, outside.position.y)]:
		worst_margin = maxf(worst_margin, absf(finished.height_at(corner) - VillageFinishedGround.given_at(plan, corner)))
	if worst_margin > 0.15:
		res.fail("finished: the margin is %.2f m off the given ground" % worst_margin)
	var moved: Dictionary = VillageFinishedGround.moved(plan, finished)
	if float(moved["changed_m2"]) <= 0.0 or float(moved["changed_m2"]) > float(moved["site_m2"]) + 1.0:
		res.fail("finished: %s m2 of a %s m2 site moved" % [moved["changed_m2"], moved["site_m2"]])
	res.note("finished ground: %d x %d nodes at %.1f m, cut to %.2f m, fill to %.2f m, %.0f of %.0f m2 moved" % [
		finished.cols, finished.rows, finished.cell_m, float(moved["cut_max_m"]), float(moved["fill_max_m"]),
		float(moved["changed_m2"]), float(moved["site_m2"])])


## The earthworks block and its two grids, read back as a consumer reads them.
static func _written(res: SuiteResult, plan: VillagePlan, given: VillageTerrain, eased: Dictionary,
		tried: Array) -> void:
	var dir: String = OS.get_user_data_dir().path_join("vgroundshape")
	DirAccess.make_dir_recursive_absolute(dir)
	var works: Dictionary = EXPORTER.write_earthworks(plan, given, eased, tried, dir.path_join("hamlet.json"), "", "")
	res.checked += 6
	if works.has("error") or works["finished"] == null or works["eased"] == null:
		res.fail("written: the earthworks of an eased plan lack a grid: %s" % [works])
		return
	if String(works["policy"]) != EXPORTER.GROUND_SHAPE or float(works["keep_relief"]) != float(eased["keep"]) \
			or works["tried"] != tried or String(works["given_fingerprint"]) != given.fingerprint():
		res.fail("written: the block does not say what was done: %s" % [works])
	var ground := VillageTerrain.from_file(dir.path_join(String(works["finished"]["file"])))
	if not ground.valid() or ground.fingerprint() != String(works["finished"]["fingerprint"]):
		res.fail("written: the finished ground does not read back as written (%s)" % [ground.errors()])
	var site: Array = works["finished"]["site_m"]
	if not Rect2(float(site[0]), float(site[1]), float(site[2]), float(site[3])).is_equal_approx(plan.site):
		res.fail("written: finished.site_m %s is not the plan's site %s" % [site, plan.site])
	var lift := VillageTerrain.from_file(dir.path_join(String(works["eased"]["lift"]["file"])))
	if not lift.valid() or lift.fingerprint() != String(works["eased"]["lift"]["fingerprint"]) \
			or lift.cols != given.cols or lift.rows != given.rows:
		res.fail("written: the lift does not read back on the given lattice (%s)" % [lift.errors()])
	# what a consumer makes of them is the ground the plan stands on
	var probe: Vector2 = plan.site.get_center() + Vector2(3.0, -2.0)
	var on_given: Vector2 = plan.ground.to_parent(probe)
	var made: float = given.height_at(on_given) + lift.height_at(on_given)
	if absf(made - (eased["terrain"] as VillageTerrain).height_at(on_given)) > 1e-3:
		res.fail("written: given + lift is not the eased ground at the site's middle")
	# and a plan on the ground as given writes no lift
	var plain: Dictionary = EXPORTER.write_earthworks(plan, given, VillageGroundEasing.eased(given, 1.0), tried,
		dir.path_join("plain.json"), "", "")
	res.checked += 1
	if plain.has("error") or plain["eased"] != null or FileAccess.file_exists(dir.path_join("plain.lift.json")):
		res.fail("written: a plan on the ground as given wrote a lift")
