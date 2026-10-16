extends RefCounted
## VillageSiteAnalysis: reading the ground before a planner places anything
## (docs/VILLAGE_TERRAIN.md, "Reading the ground").
##
##   every synthetic landform: its DEFINING cells carry the class the formula
##   says they must (crest top, spur ridge and flanks, valley thalweg and sides,
##   cliff step and both shelves, plane caps, wet exactly at or below the water
##   level with a shore band, the river channel, the saddle centre)
##   drainage: streams on the valley follow the thalweg; none where water was given
##   level_regions finds the crest's 40 m top; contours on plane_15 are straight
##   lines at the right z
##   flat ground is one class, no streams, all buildable; the cache returns the
##   same reading and stays bounded; two computations agree
##   the twelve real 30 m grids read without NaN; class histograms as notes

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const REAL30_DIR := "res://tests/fixtures/terrain/real30/"
const SITE := Rect2(-200, -200, 400, 400)
## Hallstatt's fixture carries no water_level_m, but the grid records the
## Hallstaetter See as 1327 nodes at 503 m; the suite supplies that surface.
const REAL30_WATER := {"hallstatt": 503.0}
const REAL30_SITE := Rect2(-400, -400, 800, 800)


static func run() -> SuiteResult:
	var res := SuiteResult.new("vanalysis")
	var t0 := Time.get_ticks_msec()
	VillageSiteAnalysis.clear_cache()
	_refusal(res)
	_crest(res)
	_spur(res)
	_valley(res)
	_cliff(res)
	_planes(res)
	_water(res)
	_saddle(res)
	_flat(res)
	_cache_and_determinism(res)
	_real30(res)
	res.note("vanalysis: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func _analyse(name: String, site := SITE) -> VillageSiteAnalysis:
	return VillageSiteAnalysis.of(SYNTH.make(name), site, 5.0)


## Every site cell whose centre satisfies `pred`; fails if there are none.
static func _cells(res: SuiteResult, a: VillageSiteAnalysis, label: String, pred: Callable) -> Array:
	var out: Array = []
	for idx in range(a.cell_count()):
		if pred.call(a.cell_center(idx)):
			out.append(idx)
	if out.is_empty():
		res.fail("%s: no cells selected" % label)
	return out


static func _expect_class(res: SuiteResult, a: VillageSiteAnalysis, label: String, pred: Callable,
		want: StringName) -> void:
	res.checked += 1
	var bad: Array = []
	var cells := _cells(res, a, label, pred)
	for idx in cells:
		if a.class_of(idx) != want:
			bad.append("%s=%s" % [a.cell_center(idx), a.class_of(idx)])
	if not bad.is_empty():
		res.fail("%s: %d of %d cells are not %s, e.g. %s" % [label, bad.size(), cells.size(), want,
			", ".join(PackedStringArray(bad.slice(0, 4)))])


static func _refusal(res: SuiteResult) -> void:
	res.checked += 1
	var bad := VillageSiteAnalysis.compute(VillageTerrain.from_dict({"schema": "nope"}), SITE)
	if bad.valid() or bad.errors().is_empty():
		res.fail("an analysis of unreadable ground reports valid")
	res.checked += 1
	var fine := VillageSiteAnalysis.compute(SYNTH.make("plane_5"), SITE, 1.0)
	if not is_equal_approx(fine.cell_m, 2.5):
		res.fail("a 1 m analysis cell on 5 m ground is %s m, expected the floor 2.5 m" % fine.cell_m)


static func _crest(res: SuiteResult) -> void:
	var a := _analyse("crest")
	_expect_class(res, a, "crest top (r <= 15)", func(p: Vector2) -> bool: return p.length() <= 15.0,
		VillageSiteAnalysis.CREST)
	res.checked += 1
	var regions := a.level_regions(VillageSiteAnalysis.LEVEL_MAX, 400.0)
	if regions.is_empty():
		res.fail("crest: level_regions found no level ground")
		return
	var top: Dictionary = regions[0]
	var area := float(top["area_m2"])
	if not (top["cells"] as PackedInt32Array).has(a.cell_at(Vector2(2.5, 2.5))) or area < 800.0 or area > 2500.0 \
			or absf(float(top["mean_m"]) - 60.0) > 1.0 or a.highest_point(top).length() > 20.0:
		res.fail("crest: largest level region is not the 40 m top: area %.0f m2, mean %.1f m, highest %s" % [
			area, top["mean_m"], a.highest_point(top)])


static func _spur(res: SuiteResult) -> void:
	var a := _analyse("spur")
	_expect_class(res, a, "spur ridge-line (|x| = 2.5)",
		func(p: Vector2) -> bool: return absf(p.x) < 3.0 and absf(p.y) <= 150.0, VillageSiteAnalysis.SPUR)
	_expect_class(res, a, "spur flanks (100 <= |x| <= 190)",
		func(p: Vector2) -> bool: return absf(p.x) >= 100.0 and absf(p.x) <= 190.0 and absf(p.y) <= 150.0,
		VillageSiteAnalysis.OPEN_SLOPE)


static func _valley(res: SuiteResult) -> void:
	var a := _analyse("valley")
	_expect_class(res, a, "valley thalweg (|z| = 2.5)",
		func(p: Vector2) -> bool: return absf(p.y) < 3.0, VillageSiteAnalysis.VALLEY_FLOOR)
	_expect_class(res, a, "valley sides (80 <= |z| <= 190)",
		func(p: Vector2) -> bool: return absf(p.y) >= 80.0 and absf(p.y) <= 190.0,
		VillageSiteAnalysis.OPEN_SLOPE)
	res.checked += 1
	var lines := a.streams()
	var length := 0.0
	var off: Array = []
	for line in lines:
		for k in range(line.size()):
			if absf(line[k].y) > 2.5 + a.cell_m:
				off.append(line[k])
			if k > 0:
				length += line[k].distance_to(line[k - 1])
	if lines.is_empty() or length < 100.0 or not off.is_empty():
		res.fail("valley streams: %d lines, %.0f m, %d points off the thalweg (e.g. %s)" % [
			lines.size(), length, off.size(), off.slice(0, 3)])
	else:
		res.note("valley: %d stream lines, %.0f m, all within one cell of the thalweg" % [lines.size(), length])
	# a stream drains more ground downstream than up
	res.checked += 1
	if a.flow_area_at(Vector2(190, 2.5)) <= a.flow_area_at(Vector2(20, 2.5)):
		res.fail("valley: flow area does not grow toward the outlet (%.0f at x=20, %.0f at x=190)" % [
			a.flow_area_at(Vector2(20, 2.5)), a.flow_area_at(Vector2(190, 2.5))])


static func _cliff(res: SuiteResult) -> void:
	var a := _analyse("cliff_band")
	res.checked += 1
	var step := _cells(res, a, "cliff step row", func(p: Vector2) -> bool: return absf(p.y - 47.5) < 0.1)
	for idx in step:
		if a.slope_max_of(idx) <= VillageSiteAnalysis.PATH_MAX or a.buildable_of(idx, &"path"):
			res.fail("cliff: step cell %s is buildable (slope_max %.2f)" % [a.cell_center(idx), a.slope_max_of(idx)])
			break
	res.checked += 1
	var sides := _cells(res, a, "cliff shelves", func(p: Vector2) -> bool: return absf(p.y - 47.5) > 1.0)
	for idx in sides:
		if not a.buildable_of(idx, &"plot"):
			res.fail("cliff: shelf cell %s is not plot-buildable (slope_max %.2f)" % [
				a.cell_center(idx), a.slope_max_of(idx)])
			break


static func _planes(res: SuiteResult) -> void:
	var p5 := _analyse("plane_5")
	res.checked += 1
	for idx in range(p5.cell_count()):
		if not p5.buildable_of(idx, &"cart"):
			res.fail("plane_5: cell %s not cart-buildable (slope %.3f)" % [p5.cell_center(idx), p5.slope_max_of(idx)])
			break
	var p50 := _analyse("plane_50")
	res.checked += 1
	for idx in range(p50.cell_count()):
		if p50.buildable_of(idx, &"plot") or not p50.buildable_of(idx, &"path"):
			res.fail("plane_50: cell %s plot-buildable or not path-buildable (slope %.3f)" % [
				p50.cell_center(idx), p50.slope_max_of(idx)])
			break
	# contours on plane_15: h = 100 - 0.15 z, so level L lies on z = (100 - L) / 0.15
	var p15 := _analyse("plane_15")
	res.checked += 1
	var lines := p15.contours(5.0)
	var levels := {}
	for line in lines:
		var lv := float(line["height_m"])
		levels[lv] = true
		var z := (100.0 - lv) / 0.15
		var pts: PackedVector2Array = line["points"]
		var zmin := INF
		var zmax := -INF
		for q in pts:
			zmin = minf(zmin, q.y)
			zmax = maxf(zmax, q.y)
		if absf(zmin - z) > p15.cell_m or absf(zmax - z) > p15.cell_m or zmax - zmin > 0.01 \
				or pts.size() < 2 or absf(pts[pts.size() - 1].x - pts[0].x) < 380.0:
			res.fail("plane_15: the %.0f m contour is not a straight line at z=%.2f (z %.2f..%.2f, %d points)" % [
				lv, z, zmin, zmax, pts.size()])
			break
	# the site's centres run z = -197.5 .. 197.5: h = 129.625 .. 70.375 -> 75 .. 125 every 5 m
	if levels.size() != 11 or lines.size() != 11:
		res.fail("plane_15: %d contour lines on %d levels, expected 11 straight lines" % [lines.size(), levels.size()])


static func _water(res: SuiteResult) -> void:
	for spec in [["lake_shore", Rect2(-200, 50, 400, 300)], ["island", Rect2(-300, -300, 600, 600)]]:
		var name: String = spec[0]
		var a := _analyse(name, spec[1])
		var wl := a.water_level_m
		res.checked += 1
		var wrong := 0
		var wet := 0
		for idx in range(a.cell_count()):
			var h := a.terrain.height_at(a.cell_center(idx))
			if a.wet_of(idx) != (h <= wl):
				wrong += 1
			if a.wet_of(idx):
				wet += 1
		if wrong > 0 or wet == 0:
			res.fail("%s: %d cells wet where the ground is not at or below %.1f m (%d wet)" % [name, wrong, wl, wet])
		res.checked += 1
		var shore := 0
		var missing: Array = []
		for idx in range(a.cell_count()):
			if a.class_of(idx) == VillageSiteAnalysis.SHORE:
				shore += 1
				if a.water_distance_of(idx) > VillageSiteAnalysis.SHORE_M:
					missing.append("far %s" % a.cell_center(idx))
			elif not a.wet_of(idx) and _touches_wet(a, idx):
				missing.append("not shore %s=%s" % [a.cell_center(idx), a.class_of(idx)])
		if shore == 0 or not missing.is_empty():
			res.fail("%s: shore band wrong (%d shore cells): %s" % [name, shore, missing.slice(0, 4)])
		res.checked += 1
		if not a.streams().is_empty():
			res.fail("%s: streams() drew streams on ground whose water was given" % name)
	res.checked += 1
	var lake := _analyse("lake_shore", Rect2(-200, 50, 400, 300))
	for z in [172.5, 177.5, 182.5, 187.5, 192.5, 197.5]:
		if lake.class_at(Vector2(0, z)) != VillageSiteAnalysis.SHORE:
			res.fail("lake_shore: (0, %.1f), %.1f m from the waterline, is %s, not shore" % [
				z, 200.0 - z, lake.class_at(Vector2(0, z))])
			break
	var river := _analyse("river_valley")
	_expect_class(res, river, "river_valley channel (|z| = 2.5)",
		func(p: Vector2) -> bool: return absf(p.y) < 3.0, VillageSiteAnalysis.WATER)


static func _touches_wet(a: VillageSiteAnalysis, idx: int) -> bool:
	var i := idx % a.nx
	var j := idx / a.nx
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var x := i + di
			var y := j + dj
			if x >= 0 and y >= 0 and x < a.nx and y < a.ny and a.wet_of(y * a.nx + x):
				return true
	return false


## The pass centre reads FLAT: level, and its ridge (along z) and trough
## (along x) cancel in the TPI. Documented in VillageSiteAnalysis's header.
static func _saddle(res: SuiteResult) -> void:
	var a := _analyse("saddle")
	_expect_class(res, a, "saddle centre (|x|,|z| <= 10)",
		func(p: Vector2) -> bool: return absf(p.x) <= 10.0 and absf(p.y) <= 10.0, VillageSiteAnalysis.FLAT)


static func _flat(res: SuiteResult) -> void:
	var a := VillageSiteAnalysis.of(VillageTerrain.flat(SITE, 12.0), SITE)
	res.checked += 1
	var h := a.histogram()
	if int(h[VillageSiteAnalysis.FLAT]) != a.cell_count():
		res.fail("flat ground is not all `flat`: %s" % h)
	res.checked += 1
	if not a.streams().is_empty():
		res.fail("flat ground has %d streams" % a.streams().size())
	res.checked += 1
	for idx in range(a.cell_count()):
		if not a.buildable_of(idx, &"cart"):
			res.fail("flat ground: cell %s not cart-buildable" % a.cell_center(idx))
			break
	res.checked += 1
	if not a.best_bench().is_empty():
		res.fail("flat ground has a bench")


static func _cache_and_determinism(res: SuiteResult) -> void:
	res.checked += 1
	var ground := SYNTH.make("spur")
	var a := VillageSiteAnalysis.of(ground, SITE)
	var b := VillageSiteAnalysis.of(SYNTH.make("spur"), SITE)
	if a != b:
		res.fail("cache: the same ground read twice gave two analyses")
	res.checked += 1
	var fresh := VillageSiteAnalysis.compute(ground, SITE)
	if fresh.ascii_map() != a.ascii_map() or fresh.histogram() != a.histogram():
		res.fail("determinism: two computations of the spur differ")
	res.checked += 1
	if VillageSiteAnalysis.cache_size() > VillageSiteAnalysis.CACHE_MAX:
		res.fail("cache holds %d analyses, bound is %d" % [VillageSiteAnalysis.cache_size(), VillageSiteAnalysis.CACHE_MAX])


static func _real30(res: SuiteResult) -> void:
	var files := DirAccess.get_files_at(REAL30_DIR)
	files.sort()
	var counted := 0
	for f in files:
		if not f.ends_with(".json"):
			continue
		var name := f.get_basename()
		var ground := VillageTerrain.from_file(REAL30_DIR + f)
		res.checked += 1
		if not ground.valid():
			res.fail("real30 %s: %s" % [name, ground.errors()])
			continue
		if REAL30_WATER.has(name):
			ground.water_level_m = REAL30_WATER[name]
		var a := VillageSiteAnalysis.of(ground, REAL30_SITE, 5.0)
		counted += 1
		var nan := 0
		for idx in range(a.cell_count()):
			if is_nan(a.height_of(idx)) or is_nan(a.slope_of(idx)) or is_nan(a.tpi_of(idx)):
				nan += 1
		var h := a.histogram()
		var present := 0
		var parts := PackedStringArray()
		var ranked: Array = h.keys()
		ranked.sort_custom(func(x, y) -> bool: return h[x] > h[y] or (h[x] == h[y] and String(x) < String(y)))
		for k in ranked:
			if int(h[k]) > 0:
				present += 1
				parts.append("%s %d%%" % [k, int(round(100.0 * h[k] / a.cell_count()))])
		if not a.valid() or nan > 0 or present < 2:
			res.fail("real30 %s: valid %s, %d NaN cells, %d classes" % [name, a.valid(), nan, present])
		res.note("vanalysis real30 %-13s %dx%d @ %.0f m%s: %s" % [name, a.nx, a.ny, a.cell_m,
			"" if is_nan(a.water_level_m) else " (water %.0f m)" % a.water_level_m, ", ".join(parts)])
		# the readings the survey predicts
		var share := func(keys: Array) -> float:
			var s := 0
			for k in keys:
				s += int(h[k])
			return float(s) / a.cell_count()
		match name:
			"hallstatt":
				res.checked += 1
				var dry: float = 1.0 - share.call([VillageSiteAnalysis.WATER])
				var steep_shore: float = share.call([VillageSiteAnalysis.OPEN_SLOPE, VillageSiteAnalysis.SHORE])
				if steep_shore < 0.5 * dry:
					res.fail("real30 hallstatt: open_slope + shore is %.0f%% of the dry site" % (100.0 * steep_shore / dry))
			"monpazier", "satemin":
				res.checked += 1
				var lvl: float = share.call([VillageSiteAnalysis.FLAT, VillageSiteAnalysis.BENCH])
				if lvl < 0.5:
					res.fail("real30 %s: flat + bench is only %.0f%%" % [name, 100.0 * lvl])
	res.checked += 1
	if counted != 12:
		res.fail("real30: read %d grids, expected 12" % counted)
