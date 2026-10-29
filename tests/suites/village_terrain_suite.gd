extends RefCounted
## VillageTerrain, the reader for the ground a village stands on
## (docs/VILLAGE_TERRAIN.md), and the exporter's use of it.
##
##   a bad grid is refused with a reason, never half-read
##   inline, raw-file and sampler readings of the same ground agree exactly
##   height, gradient, `under()` and `profile()` are right on a known plane
##   a footprint crossed by a cliff is seen even when its centre is gentle
##   real ground from the world survey reads, steep where it should be
##   a SitePlan with ground has a reading under every lot, building and road,
##   says where it stands, and keeps every key the flat SitePlan has; a flat
##   request grows no ground block; the plan purity check tells two grounds
##   apart

const EXPORTER := preload("res://tools/export_village_plan.gd")
const HAMLET := "res://tests/fixtures/site_requests/thorn-hamlet.json"
const REAL := {
	"res://tests/fixtures/terrain/manarola.json": [120.0, 1e9],
	"res://tests/fixtures/terrain/limone_sul_garda.json": [200.0, 1e9],
	"res://tests/fixtures/terrain/varennes.json": [0.0, 20.0],
}
const EPS := 1e-4
const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const REAL30_DIR := "res://tests/fixtures/terrain/real30/"
## name -> [probe x, probe z, expected dh/dx, expected dh/dz, expected relief m].
## The formulas are in synthetic_terrain.gd's header.
const SYNTH_EXPECT := {
	"plane_5": [10.0, 20.0, 0.0, -0.05, 40.0],
	"plane_15": [10.0, 20.0, 0.0, -0.15, 120.0],
	"plane_30": [10.0, 20.0, 0.0, -0.30, 240.0],
	"plane_50": [10.0, 20.0, 0.0, -0.50, 400.0],
	"valley": [0.0, 100.0, 0.0, 0.30, 111.0],
	"river_valley": [0.0, 100.0, 0.0, 0.30, 114.0],
	"spur": [100.0, 0.0, -0.25, -0.10, 180.0],
	"crest": [170.0, 0.0, -0.20, 0.0, 60.0],
	"saddle": [100.0, 0.0, 0.10, 0.0, 160.0],
	"cliff_band": [0.0, 47.5, 0.0, 3.0, 15.0],
	"lake_shore": [0.0, 0.0, 0.0, -0.08, 64.0],
	"island": [100.0, 0.0, -0.16, 0.0, 50.0],
	# on the land where the shore line's own slope is nil (x = 35 pi)
	"lagoon": [109.956, -100.0, 0.0, -0.03, 16.1],
}
## Relief (m) over the inner +-430 m, measured from the 90 m Mapzen DEM that
## `survey.py terrain` caches (OpenTopoData mapzen, nodes with |x|,|y| <= 430
## of the 790 m site DEM), which is the ground the 90 m fixtures are cut from.
## Manarola and Limone are the whole-file reliefs of the existing fixtures.
const REAL30_90M_RELIEF := {
	"hallstatt": 492.0,
	"manarola": 194.0,
	"masouleh": 379.0,
	"positano": 361.0,
	"rocamadour": 137.0,
	"castelmezzano": 323.0,
	"monemvasia": 165.0,
	"ushguli": 181.0,
	"eze": 377.0,
	"monpazier": 58.0,
	"giethoorn": 8.0,
	"satemin": 9.0,
}
## Per-site tolerance where the 30 m grid resolves what 90 m smooths; the
## reason sits beside the entry. Default 0.15.
const REAL30_TOL := {
	# 30 m resolves the ravine walls and the harbour cliff that a 90 m cell averages away: 230 m vs 194 m
	"manarola": 0.20,
	# flat polder / Wendland plain: relief is 8-11 m, so one or two whole metres of SRTM
	# integer quantisation and the 90 m / 30 m source difference is 20-25 %
	"giethoorn": 0.30,
	"satemin": 0.30,
}


static func run() -> SuiteResult:
	var res := SuiteResult.new("vterrain")
	_refusals(res)
	_plane(res)
	_readers_agree(res)
	_cliff(res)
	_real(res)
	_synthetic(res)
	_real30(res)
	_exporter(res)
	_capacity(res)
	return res


## BG-012-EARLY-REFUSE: VillageCapacity on hand-made jobs (no building is
## generated). A cottage-sized programme on dry plane ground fits; the same
## programme on a drowned plain, on a 100 % wall, and with a castle that needs a
## clear disc the dry hump does not have, is refused, each naming its rule.
static func _capacity(res: SuiteResult) -> void:
	var rect := Rect2(-400, -400, 800, 800)
	var grounds := {
		"plane": VillageTerrain.from_sampler(func(_x: float, z: float) -> float: return 100.0 - 0.3 * z, rect, 5.0),
		"drowned": VillageTerrain.from_sampler(func(x: float, z: float) -> float:
			return 10.0 if Vector2(x, z).length() < 8.0 else 0.0, rect, 5.0, 5.0),
		"wall": VillageTerrain.from_sampler(func(_x: float, z: float) -> float: return z, rect, 5.0),
		# dry ground 28 m wide between two lakes: room for the cottages, not for a castle's disc
		"strip": VillageTerrain.from_sampler(func(_x: float, z: float) -> float:
			return 10.0 if absf(z) < 14.0 else 0.0, rect, 5.0, 5.0),
	}
	var small := BuildingRequest.new()
	small.kind = &"house"
	var big := BuildingRequest.new()
	big.kind = &"castle"
	var hold := func(count: int, castle: bool) -> Array[Dictionary]:
		var jobs: Array[Dictionary] = []
		for i in range(count):
			jobs.append({"request": small, "class": &"cottage", "footprint": Rect2(-4, -3, 8, 6)})
		if castle:
			jobs.append({"request": big, "class": &"manor", "footprint": Rect2(-40, -40, 80, 80)})
		return jobs
	var want := {"plane": false, "drowned": true, "wall": true, "strip": true}
	for name in grounds:
		var spec := VillageSpec.new(1)
		spec.form = &"street"
		var plan := VillagePlan.new(spec)
		plan.site = Rect2(-60, -45, 120, 90)
		plan.ground = grounds[name]
		var jobs: Array[Dictionary] = hold.call(12, name == "strip")
		var got := VillageCapacity.estimate(plan, jobs)
		res.checked += 2
		if got.is_empty() or bool(got["refuse"]) != bool(want[name]):
			res.fail("capacity %s: refuse is %s, wanted %s (%s)" % [name, got.get("refuse"), want[name], got.get("reason")])
		if bool(want[name]) and (got["rules"] as Array).is_empty():
			res.fail("capacity %s: a refusal names no rule" % name)
	# the wet ground is named wet, the wall cliff
	var drowned := VillageCapacity.estimate(_plan_on(grounds["drowned"]), hold.call(12, false))
	var wall := VillageCapacity.estimate(_plan_on(grounds["wall"]), hold.call(12, false))
	res.checked += 2
	if float(drowned["rules"][0]["share"]) < 0.9 or String(drowned["rules"][0]["rule"]) != "wet":
		res.fail("capacity: drowned ground is not mostly wet: %s" % [drowned["rules"]])
	if float(wall["rules"][1]["share"]) < 0.9 or String(wall["rules"][1]["rule"]) != "cliff":
		res.fail("capacity: the wall is not mostly cliff: %s" % [wall["rules"]])
	# a water village stands in the water: no estimate, never a refusal
	var water_plan := _plan_on(grounds["drowned"])
	water_plan.spec.form = &"water"
	res.checked += 1
	if not VillageCapacity.estimate(water_plan, hold.call(12, false)).is_empty():
		res.fail("capacity: a water village was estimated against its own water")


static func _plan_on(ground: VillageTerrain) -> VillagePlan:
	var spec := VillageSpec.new(1)
	spec.form = &"street"
	var plan := VillagePlan.new(spec)
	plan.site = Rect2(-60, -45, 120, 90)
	plan.ground = ground
	return plan


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
##
## Since VTER-SITING / VTER-ROADS the planners USE the ground (owner decision
## 1: a plan given terrain may differ from the flat plan), so the two are
## planned separately -- the buildings measured once -- and the check that
## the ground "changed nothing" is replaced by: every key the flat SitePlan
## has, at every level the contract fixes, is still present with the same
## type; the sited plan says where it stands; and a flat request still grows
## no ground block. Byte-identity of flat output is the exporter diff in
## docs/VILLAGE_TERRAIN.md, not this suite.
static func _exporter(res: SuiteResult) -> void:
	var raw := FileAccess.get_file_as_string(HAMLET)
	var request: Dictionary = JSON.parse_string(raw)
	var ground := VillageTerrain.from_file("res://tests/fixtures/terrain/manarola.json")
	var flat_spec := _spec(request, raw, null)
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(flat_spec))
	var flat_plan: VillagePlan = VillageLotPlanner.plan_measured(flat_spec, jobs)
	var plan: VillagePlan = VillageLotPlanner.plan_measured(_spec(request, raw, ground), jobs)
	var hilly: Dictionary = JSON.parse_string(JSON.stringify(EXPORTER.site_plan(plan, request), "	", true))
	var flat: Dictionary = JSON.parse_string(JSON.stringify(EXPORTER.site_plan(flat_plan, request), "	", true))
	res.checked += 1
	if flat.has("ground") or (flat["buildings"] as Array).any(func(b): return b.has("ground")) 			or (flat["site"] as Dictionary).has("anchor_m"):
		res.fail("exporter: a request without terrain grew a ground block")
	res.checked += 1
	if not hilly.has("ground") or String(hilly["ground"]["fingerprint"]) != ground.fingerprint():
		res.fail("exporter: the plan on Manarola has no site ground, or the wrong one")
		return
	res.checked += 1
	var site: Dictionary = hilly["site"]
	if not site.has("anchor_m") or not site.has("yaw_deg") or (site["anchor_m"] as Array).size() != 2:
		res.fail("exporter: the plan on Manarola does not say where it stands (site.anchor_m, site.yaw_deg)")
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
	# with ground the SitePlan also says which form the ground derived
	# (VTER-FORM-DERIVE); a flat one never does
	res.checked += 1
	if String(hilly.get("form_intent", "")) != String(plan.spec.form_intent) or flat.has("form_intent"):
		res.fail("exporter: form_intent is missing with ground, or present without it")
	hilly.erase("form_intent")
	# the ground may change the plan, never its shape: every key the flat
	# plan has, the sited plan has, with the same type, down every level
	var missing: Array[String] = []
	_same_keys(flat, hilly, "", missing)
	res.checked += 1
	if not missing.is_empty():
		res.fail("exporter: the sited plan lost or retyped SitePlan keys: %s" % ", ".join(missing.slice(0, 6)))
	# and it is still a plan: roads, lots, buildings, every building on a lot
	res.checked += 1
	if (hilly["roads"] as Array).is_empty() or (hilly["buildings"] as Array).size() != (flat["buildings"] as Array).size():
		res.fail("exporter: the sited plan has %d buildings, the flat plan %d" % [
			(hilly["buildings"] as Array).size(), (flat["buildings"] as Array).size()])
	# two grounds, two plans as far as purity is concerned
	var a := _spec(request, raw, ground)
	var b := _spec(request, raw, VillageTerrain.from_file("res://tests/fixtures/terrain/varennes.json"))
	res.checked += 1
	if VillagePlan._spec_equal(a, b) or not VillagePlan._spec_equal(a, _spec(request, raw, ground)):
		res.fail("exporter: the plan purity check does not tell two grounds apart")


## Every key of `flat` is in `sited` with a value of the same JSON type; a
## list is compared through its first row (rows are alike).
static func _same_keys(flat: Variant, sited: Variant, at: String, missing: Array[String]) -> void:
	if flat is Dictionary:
		if not sited is Dictionary:
			missing.append(at + " (not an object)")
			return
		for k in flat:
			if k == "notes":
				continue
			if not (sited as Dictionary).has(k):
				missing.append(at + "." + str(k))
				continue
			_same_keys(flat[k], sited[k], at + "." + str(k), missing)
	elif flat is Array:
		if not sited is Array:
			missing.append(at + " (not a list)")
			return
		if not (flat as Array).is_empty() and not (sited as Array).is_empty():
			_same_keys(flat[0], sited[0], at + "[0]", missing)
	elif flat != null and sited != null and typeof(flat) != typeof(sited):
		missing.append(at + " (%s, was %s)" % [type_string(typeof(sited)), type_string(typeof(flat))])


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


## Every landform builds, and its slope at a defining point and its relief
## match the formula (synthetic_terrain.gd) within 1 %.
static func _synthetic(res: SuiteResult) -> void:
	var names: PackedStringArray = SYNTH.names()
	res.checked += 1
	if names.size() != SYNTH_EXPECT.size():
		res.fail("synthetic: %d landforms, %d expectations" % [names.size(), SYNTH_EXPECT.size()])
	for n in names:
		var t: VillageTerrain = SYNTH.make(n)
		res.checked += 1
		if not t.valid() or not t.covers(Rect2(-400, -400, 800, 800)):
			res.fail("synthetic: %s invalid or does not cover 800 m: %s" % [n, t.errors()])
			continue
		if not SYNTH_EXPECT.has(n):
			res.fail("synthetic: %s has no expectation" % n)
			continue
		var e: Array = SYNTH_EXPECT[n]
		var g := t.gradient_at(Vector2(e[0], e[1]))
		var want := Vector2(e[2], e[3])
		res.checked += 1
		if absf(g.length() - want.length()) > 0.01 * want.length() or g.distance_to(want) > 0.01 * want.length():
			res.fail("synthetic: %s gradient %s at (%s, %s), want %s" % [n, g, e[0], e[1], want])
		res.checked += 1
		if absf(t.relief() - float(e[4])) > 0.01 * float(e[4]):
			res.fail("synthetic: %s relief %.2f m, want %.0f" % [n, t.relief(), e[4]])
	# standing water
	var lake: VillageTerrain = SYNTH.make("lake_shore")
	res.checked += 1
	if not lake.is_wet(Vector2(0, 300)) or lake.is_wet(Vector2(0, 100)) or absf(lake.water_level_m - 4.0) > EPS:
		res.fail("synthetic: lake_shore is not wet in the south quarter only")
	var river: VillageTerrain = SYNTH.make("river_valley")
	res.checked += 1
	if not river.is_wet(Vector2(0, 0)) or river.is_wet(Vector2(0, 20)):
		res.fail("synthetic: river_valley water is not confined to the channel")
	var isle: VillageTerrain = SYNTH.make("island")
	res.checked += 1
	if isle.is_wet(Vector2(0, 0)) or not isle.is_wet(Vector2(380, 0)):
		res.fail("synthetic: island is not dry on the cone and wet in the sea")
	var cliff: VillageTerrain = SYNTH.make("cliff_band")
	res.checked += 1
	if absf(cliff.height_at(Vector2(0, 40)) - 10.0) > EPS or absf(cliff.height_at(Vector2(0, 60)) - 25.0) > EPS:
		res.fail("synthetic: cliff_band is not 10 m north and 25 m south of z = 50")
	# deterministic, and a different cell size is still the same ground
	res.checked += 1
	if SYNTH.make("spur").fingerprint() != SYNTH.make("spur").fingerprint():
		res.fail("synthetic: spur is not deterministic")
	var fine: VillageTerrain = SYNTH.make("saddle", Rect2(-100, -100, 200, 200), 2.0)
	res.checked += 1
	if not fine.valid() or absf(fine.height_at(Vector2(60, 40)) - (40.0 + 0.0005 * (3600.0 - 1600.0))) > 0.01:
		res.fail("synthetic: saddle at 2 m disagrees with its formula")


## The 30 m real grids load, cover a 800 m site, and agree with the 90 m
## relief over the inner +-430 m.
static func _real30(res: SuiteResult) -> void:
	for slug in REAL30_90M_RELIEF:
		var t := VillageTerrain.from_file(REAL30_DIR + slug + ".json")
		res.checked += 1
		if not t.valid():
			res.fail("real30: %s refused: %s" % [slug, t.errors()])
			continue
		res.checked += 1
		if not t.covers(Rect2(-400, -400, 800, 800)) or absf(t.cell_m - 30.0) > EPS:
			res.fail("real30: %s does not cover 800 m at 30 m (cell %.1f)" % [slug, t.cell_m])
			continue
		var lo := INF
		var hi := -INF
		for r in range(t.rows):
			for c in range(t.cols):
				var p := t.origin + Vector2(c, r) * t.cell_m
				if absf(p.x) <= 430.0 and absf(p.y) <= 430.0:
					var h := t.heights[r * t.cols + c]
					lo = minf(lo, h)
					hi = maxf(hi, h)
		var inner := hi - lo
		var want: float = REAL30_90M_RELIEF[slug]
		var tol: float = REAL30_TOL.get(slug, 0.15)
		res.checked += 1
		if absf(inner - want) > tol * want:
			res.fail("real30: %s inner relief %.0f m vs 90 m %.0f m (tol %.0f %%)" % [slug, inner, want, tol * 100.0])
		else:
			res.note("real30: %s %d x %d at %.0f m, inner relief %.0f m (90 m: %.0f m), whole %.0f m" % [
				slug, t.cols, t.rows, t.cell_m, inner, want, t.relief()])
