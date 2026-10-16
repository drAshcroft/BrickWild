extends RefCounted
## VillageTerrain, the reader for the ground a village stands on
## (docs/VILLAGE_TERRAIN.md), and the exporter's use of it.
##
##   a bad grid is refused with a reason, never half-read
##   inline, raw-file and sampler readings of the same ground agree exactly
##   height, gradient, `under()` and `profile()` are right on a known plane
##   a footprint crossed by a cliff is seen even when its centre is gentle
##   real ground from the world survey reads, steep where it should be
##   a SitePlan with ground has a reading under every lot, building and road;
##   without ground it is byte-identical to before; the plan purity check
##   tells two grounds apart

const EXPORTER := preload("res://tools/export_village_plan.gd")
const HAMLET := "res://tests/fixtures/site_requests/thorn-hamlet.json"
const REAL := {
	"res://tests/fixtures/terrain/manarola.json": [120.0, 1e9],
	"res://tests/fixtures/terrain/limone_sul_garda.json": [200.0, 1e9],
	"res://tests/fixtures/terrain/varennes.json": [0.0, 20.0],
}
const EPS := 1e-4


static func run() -> SuiteResult:
	var res := SuiteResult.new("vterrain")
	_refusals(res)
	_plane(res)
	_readers_agree(res)
	_cliff(res)
	_real(res)
	_exporter(res)
	return res


## h = 0.1 x + 0.05 y + 20 over [-50, 50]^2 at 5 m.
static func _plane_height(x: float, y: float) -> float:
	return 0.1 * x + 0.05 * y + 20.0


static func _plane_terrain() -> VillageTerrain:
	return VillageTerrain.from_sampler(func(x: float, y: float) -> float: return _plane_height(x, y),
		Rect2(-50, -50, 100, 100), 5.0)


static func _grid(cols: int, rows: int, hs: Array) -> Dictionary:
	return {"schema": "brickwild.terrain", "schema_version": 1, "origin_m": [0, 0],
		"cell_m": 1.0, "cols": cols, "rows": rows, "heights_m": hs}


static func _refusals(res: SuiteResult) -> void:
	var good := _grid(2, 2, [0, 1, 2, 3])
	var cases := {
		"wrong schema": {"schema": "dmv.terrain"},
		"no version": {"schema": "brickwild.terrain"},
		"short heights": _grid(2, 2, [0, 1, 2]),
		"one column": _grid(1, 2, [0, 1]),
		"a string height": _grid(2, 2, [0, 1, "2", 3]),
		"a null height": _grid(2, 2, [0, 1, null, 3]),
		"millimetres": _grid(2, 2, [0, 1, 20000, 3]),
		"fractional cols": _merge(good, {"cols": 2.5}),
		"zero cell": _merge(good, {"cell_m": 0.0}),
		"no origin": _merge(good, {"origin_m": [0]}),
		"no heights": _without(good, "heights_m"),
		"missing file": _merge(_without(good, "heights_m"), {"file": "user://no_such_ground.r32"}),
		"text water": _merge(good, {"water_level_m": "low"}),
	}
	for label in cases:
		var t := VillageTerrain.from_dict(cases[label])
		res.checked += 1
		if t.valid() or t.errors().is_empty():
			res.fail("refusal: '%s' was accepted" % label)
	# the file must be exactly cols x rows float32
	var short := FileAccess.open("user://short_ground.r32", FileAccess.WRITE)
	short.store_float(1.0)
	short.close()
	res.checked += 1
	if VillageTerrain.from_dict(_merge(_without(good, "heights_m"), {"file": "user://short_ground.r32"})).valid():
		res.fail("refusal: a 4-byte file was read as a 2 x 2 grid")
	res.checked += 1
	if not VillageTerrain.from_dict(good).valid():
		res.fail("the minimal good grid was refused: %s" % VillageTerrain.from_dict(good).errors())
	# a spec carrying bad ground is not a valid spec
	var spec := VillageSpec.new(1)
	spec.terrain = VillageTerrain.from_dict(cases["short heights"])
	res.checked += 1
	if spec.valid():
		res.fail("a VillageSpec with unreadable terrain reports valid")


static func _plane(res: SuiteResult) -> void:
	var t := _plane_terrain()
	res.checked += 1
	if not t.valid():
		res.fail("plane: %s" % t.errors())
		return
	for p in [Vector2(-50, -50), Vector2(12.5, -7.25), Vector2(33.3, 41.1), Vector2(50, 50)]:
		res.checked += 1
		if absf(t.height_at(p) - _plane_height(p.x, p.y)) > EPS:
			res.fail("plane: height at %s is %.5f, want %.5f" % [p, t.height_at(p), _plane_height(p.x, p.y)])
	res.checked += 1
	if t.gradient_at(Vector2(3, 4)).distance_to(Vector2(0.1, 0.05)) > EPS:
		res.fail("plane: gradient %s, want (0.1, 0.05)" % t.gradient_at(Vector2(3, 4)))
	res.checked += 1
	if not t.covers(Rect2(-50, -50, 100, 100)) or t.covers(Rect2(-50, -50, 101, 100)):
		res.fail("plane: covers() is wrong at the grid's edge")
	# a 20 x 10 plot from (0, 0): falls 2 + 0.5 = 2.5 m, low at its NW corner
	var plot := PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 10), Vector2(0, 10)])
	var u := t.under(plot)
	res.checked += 1
	if absf(float(u["span_m"]) - 2.5) > EPS or absf(float(u["min_m"]) - 20.0) > EPS:
		res.fail("plane: under() span %.4f min %.4f, want 2.5 and 20" % [u["span_m"], u["min_m"]])
	res.checked += 1
	if Vector2(u["low_m"][0], u["low_m"][1]).distance_to(Vector2(0, 0)) > EPS \
			or Vector2(u["high_m"][0], u["high_m"][1]).distance_to(Vector2(20, 10)) > EPS:
		res.fail("plane: under() low %s high %s, want (0, 0) and (20, 10)" % [u["low_m"], u["high_m"]])
	res.checked += 1
	if absf(float(u["slope_max"]) - Vector2(0.1, 0.05).length()) > EPS or float(u["dry_share"]) != 1.0:
		res.fail("plane: under() slope %.4f dry %.2f" % [u["slope_max"], u["dry_share"]])
	# water at 21 m wets the plot's low half (h < 21 where 0.1x + 0.05y < 1)
	var wet := VillageTerrain.from_sampler(func(x: float, y: float) -> float: return _plane_height(x, y),
		Rect2(-50, -50, 100, 100), 5.0, 21.0)
	var dry: float = float(wet.under(plot)["dry_share"])
	res.checked += 1
	if dry <= 0.2 or dry >= 0.8:
		res.fail("plane: with water at 21 m the plot is %.2f dry, want a part" % dry)
	# a road straight up the x grade: 40 m long, rises 4 m, grade 0.1
	var pr := t.profile(PackedVector2Array([Vector2(-20, 0), Vector2(20, 0)]), 2.0)
	res.checked += 1
	if absf(float(pr["rise_m"]) - 4.0) > EPS or absf(float(pr["fall_m"])) > EPS \
			or absf(float(pr["grade_max"]) - 0.1) > EPS or absf(float(pr["length_m"]) - 40.0) > EPS:
		res.fail("plane: profile rise %.3f fall %.3f grade %.3f length %.3f" % [
			pr["rise_m"], pr["fall_m"], pr["grade_max"], pr["length_m"]])


static func _readers_agree(res: SuiteResult) -> void:
	var t := _plane_terrain()
	var inline := VillageTerrain.from_dict(t.to_dict())
	var f := FileAccess.open("user://plane_ground.r32", FileAccess.WRITE)
	f.store_buffer(t.heights.to_byte_array())
	f.close()
	var header := t.to_dict()
	header.erase("heights_m")
	header["file"] = "plane_ground.r32"
	var hf := FileAccess.open("user://plane_ground.json", FileAccess.WRITE)
	hf.store_string(JSON.stringify(header))
	hf.close()
	var from_file := VillageTerrain.from_file("user://plane_ground.json")
	res.checked += 1
	if t.save("user://saved_ground.json") != OK:
		res.fail("readers: save() could not write user://saved_ground.json")
	var saved := VillageTerrain.from_file("user://saved_ground.json")
	for pair in [["inline", inline], ["raw file", from_file], ["saved", saved]]:
		var other: VillageTerrain = pair[1]
		res.checked += 1
		if not other.valid():
			res.fail("readers: the %s reading was refused: %s" % [pair[0], other.errors()])
			continue
		if other.fingerprint() != t.fingerprint():
			res.fail("readers: the %s reading differs from the sampler's" % pair[0])
	var moved := t.to_dict()
	moved["heights_m"][7] = float(moved["heights_m"][7]) + 0.01
	res.checked += 1
	if VillageTerrain.from_dict(moved).fingerprint() == t.fingerprint():
		res.fail("readers: a 1 cm change left the fingerprint unchanged")


## A 2 m-cell grid, flat at 10 m, with a 6 m cliff along x = 3. A centre
## sample of a plot from x = -4 to 4 sees 10 m; `under()` must see the cliff.
static func _cliff(res: SuiteResult) -> void:
	var t := VillageTerrain.from_sampler(func(x: float, _y: float) -> float: return 16.0 if x >= 3.0 else 10.0,
		Rect2(-20, -20, 40, 40), 2.0)
	var plot := PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	var u := t.under(plot)
	res.checked += 1
	if absf(t.height_at(Vector2.ZERO) - 10.0) > EPS:
		res.fail("cliff: the plot's centre is not on the low ground")
	res.checked += 1
	if float(u["span_m"]) < 5.9 or float(u["slope_max"]) < 1.0:
		res.fail("cliff: under() missed the cliff: span %.2f slope %.2f" % [u["span_m"], u["slope_max"]])


static func _real(res: SuiteResult) -> void:
	for path in REAL:
		var t := VillageTerrain.from_file(path)
		res.checked += 1
		if not t.valid():
			res.fail("real: %s refused: %s" % [path.get_file(), t.errors()])
			continue
		var band: Array = REAL[path]
		res.checked += 1
		if t.relief() < band[0] or t.relief() > band[1]:
			res.fail("real: %s relief %.0f m outside [%.0f, %.0f]" % [path.get_file(), t.relief(), band[0], band[1]])
		res.checked += 1
		if not t.covers(Rect2(-200, -200, 400, 400)):
			res.fail("real: %s does not cover a 400 m site" % path.get_file())
		else:
			res.note("real: %s %d x %d at %.0f m, relief %.0f m, %s" % [path.get_file(), t.cols, t.rows,
				t.cell_m, t.relief(), "steep" if t.relief() > 100 else "gentle"])


## The exporter on the smallest real request: once flat, once on Manarola.
static func _exporter(res: SuiteResult) -> void:
	var raw := FileAccess.get_file_as_string(HAMLET)
	var request: Dictionary = JSON.parse_string(raw)
	var ground := VillageTerrain.from_file("res://tests/fixtures/terrain/manarola.json")
	# planned once (a minute of building measurement); the planners do not
	# read the ground, so the same plan is written with it and without it
	var plan: VillagePlan = VillageLotPlanner.plan(_spec(request, raw, ground))
	var hilly: Dictionary = JSON.parse_string(JSON.stringify(EXPORTER.site_plan(plan, request), "\t", true))
	plan.spec.terrain = null
	var flat: Dictionary = JSON.parse_string(JSON.stringify(EXPORTER.site_plan(plan, request), "\t", true))
	plan.spec.terrain = ground
	res.checked += 1
	if flat.has("ground") or (flat["buildings"] as Array).any(func(b): return b.has("ground")):
		res.fail("exporter: a request without terrain grew a ground block")
	res.checked += 1
	if not hilly.has("ground") or String(hilly["ground"]["fingerprint"]) != ground.fingerprint():
		res.fail("exporter: the plan on Manarola has no site ground, or the wrong one")
		return
	for key in ["lots", "buildings", "roads", "commons"]:
		for row in hilly[key]:
			res.checked += 1
			var g: Dictionary = row.get("ground", {})
			if g.is_empty():
				res.fail("exporter: a %s row has no ground" % key)
				break
			var lo: float = float(g.get("min_m", g["points_m"].min() if g.has("points_m") else 0.0))
			if lo < ground.min_height() - 0.01 or lo > ground.max_height() + 0.01:
				res.fail("exporter: a %s reads %.2f m, outside the grid's %.1f..%.1f" % [
					key, lo, ground.min_height(), ground.max_height()])
				break
	# the same plan, the ground taken away again, is the flat plan exactly
	for key in ["lots", "buildings", "roads", "commons"]:
		for row in hilly[key]:
			row.erase("ground")
	hilly.erase("ground")
	res.checked += 1
	# both sides went through one parse: JSON reads every number back as a float
	if JSON.stringify(hilly, "\t", true) != JSON.stringify(flat, "\t", true):
		res.fail("exporter: ground changed the plan itself, not only added readings")
	# two grounds, two plans as far as purity is concerned
	var a := _spec(request, raw, ground)
	var b := _spec(request, raw, VillageTerrain.from_file("res://tests/fixtures/terrain/varennes.json"))
	res.checked += 1
	if VillagePlan._spec_equal(a, b) or not VillagePlan._spec_equal(a, _spec(request, raw, ground)):
		res.fail("exporter: the plan purity check does not tell two grounds apart")


static func _spec(request: Dictionary, raw: String, ground: VillageTerrain) -> VillageSpec:
	var notes: Array[String] = []
	var spec: VillageSpec = EXPORTER.spec_from_request(request, raw, notes)
	spec.terrain = ground
	spec.generate(spec.seed)
	return spec


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	out.merge(b, true)
	return out


static func _without(a: Dictionary, key: String) -> Dictionary:
	var out := a.duplicate(true)
	out.erase(key)
	return out
