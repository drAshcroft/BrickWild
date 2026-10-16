extends RefCounted
## The world settlement coverage set (docs/SETTLEMENT_TESTSET.md): real towns
## and villages chosen to SPAN the ways settlements differ, not to average
## them, measured from OpenStreetMap and a DEM by
## tools/settlements/survey.py.
##
## Two jobs, both fast (no village is planned here):
##   1. the fixture keeps its coverage: a later regeneration or hand edit that
##      drops the polar, the arid, the steep, the island or the over-water
##      cases fails, because that is the point of the set;
##   2. every site maps to a valid VillageSpec, and the suite REPORTS (notes,
##      not failures) how often the form the generator derives from the
##      seven inputs agrees with the arrangement the real place has, and
##      which unsupported features recur. Those counts are the to-do list
##      for terrain-aware villages; they shrink as the generator learns.

const FIXTURE := "res://tests/fixtures/settlements/world_settlements.json"

## What the set must keep covering. Counts are over MEASURED sites (enough
## OSM buildings to judge).
const MIN_MEASURED := 80
const KOPPEN_GROUPS := ["A", "B", "C", "D", "E"]
const MIN_STEEP := 8          # slope_median_pct >= 20
const MIN_VERTICAL := 10      # elev_span_m >= 40
const MIN_ISLAND := 6         # landmass_km2 < 500
const MIN_OVER_WATER := 2     # over_water_share >= 0.05 (Ganvie, Kampong Ayer)
const MIN_HIGH := 2           # elev_m >= 3000
const MIN_POLAR := 2          # |lat| >= 66
const MIN_DISPERSED := 3      # nearest_form == dispersed
const MIN_FORMS := 6          # distinct nearest_form values


static func run() -> SuiteResult:
	var res := SuiteResult.new("vworld")
	var text := FileAccess.get_file_as_string(FIXTURE)
	res.checked += 1
	if text.is_empty():
		res.fail("cannot read %s" % FIXTURE)
		return res
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or data.get("schema", "") != "brickwild.settlements":
		res.fail("%s is not a brickwild.settlements document" % FIXTURE)
		return res
	var sites: Array = data["sites"]
	var measured: Array = sites.filter(func(s): return bool(s["morph"].get("usable", false)))
	res.checked += 1
	if measured.size() < MIN_MEASURED:
		res.fail("only %d measured sites, the set needs %d" % [measured.size(), MIN_MEASURED])

	_coverage(res, sites, measured)
	_specs(res, measured)
	return res


static func _count(rows: Array, pred: Callable) -> int:
	var n := 0
	for r in rows:
		if pred.call(r):
			n += 1
	return n


static func _coverage(res: SuiteResult, sites: Array, measured: Array) -> void:
	var groups := {}
	for s in measured:
		groups[String(s["env"].get("koppen", "?")).left(1)] = true
	for g in KOPPEN_GROUPS:
		res.checked += 1
		if not groups.has(g):
			res.fail("no measured site in Koppen group %s" % g)
	var floors := [
		["steep (median slope >= 20 %)", MIN_STEEP,
			func(s): return float(s["morph"].get("slope_median_pct", 0.0)) >= 20.0],
		["vertical (>= 40 m between low and high houses)", MIN_VERTICAL,
			func(s): return float(s["morph"].get("elev_span_m", 0.0)) >= 40.0],
		["island (landmass < 500 km2)", MIN_ISLAND,
			func(s): return float(s["env"].get("landmass_km2", 1e9)) < 500.0],
		["over water (>= 5 % of buildings in water)", MIN_OVER_WATER,
			func(s): return float(s["morph"].get("over_water_share", 0.0)) >= 0.05],
		["high (>= 3000 m)", MIN_HIGH,
			func(s): return float(s["env"].get("elev_m", 0.0)) >= 3000.0],
		["polar (|lat| >= 66)", MIN_POLAR,
			func(s): return absf(float(s["lat"])) >= 66.0],
		["dispersed", MIN_DISPERSED,
			func(s): return s["spec"]["nearest_form"] == "dispersed"],
	]
	for row in floors:
		res.checked += 1
		var n := _count(measured, row[2])
		if n < int(row[1]):
			res.fail("%d %s sites, the set needs %d" % [n, row[0], row[1]])
		else:
			res.note("coverage: %d %s" % [n, row[0]])
	var water := {}
	var forms := {}
	for s in measured:
		water[s["spec"]["water"]] = true
		forms[s["spec"]["nearest_form"]] = true
	for w in VillageSpec.WATERS:
		res.checked += 1
		if not water.has(String(w)):
			res.fail("no measured site maps to water '%s'" % w)
	res.checked += 1
	if forms.size() < MIN_FORMS:
		res.fail("only %d distinct measured forms %s" % [forms.size(), forms.keys()])
	for s in sites:
		if s["source"] != "curated":
			continue
		res.checked += 1
		if String(s.get("phenomenon", "")).is_empty():
			res.fail("curated site %s names no phenomenon" % s["name"])


static func _specs(res: SuiteResult, measured: Array) -> void:
	var agree := 0
	var confusion := {}
	var gaps := {}
	var sites_with_gaps := 0
	for i in range(measured.size()):
		var s: Dictionary = measured[i]
		var m: Dictionary = s["spec"]
		var spec := VillageSpec.new(9000 + i)
		spec.population = int(m["population"])
		spec.culture = StringName(m["culture"])
		spec.purpose = StringName(m["purpose"])
		spec.water = StringName(m["water"])
		spec.enclosure = StringName(m["enclosure"])
		res.checked += 1
		if not spec.valid():
			res.fail("%s maps to an invalid spec: %s" % [s["name"], "; ".join(spec.errors())])
			continue
		spec.generate(9000 + i)
		var real: String = m["nearest_form"]
		var derived := String(spec.form)
		if real == derived:
			agree += 1
		var key := "%s->%s" % [real, derived]
		confusion[key] = int(confusion.get(key, 0)) + 1
		var unsupported: Array = m["unsupported"]
		if not unsupported.is_empty():
			sites_with_gaps += 1
		for g in unsupported:
			var tag := String(g).get_slice(":", 0)
			gaps[tag] = int(gaps.get(tag, 0)) + 1
	res.note("form agreement: the spec derives the measured form for %d of %d sites" % [agree, measured.size()])
	var keys := confusion.keys()
	keys.sort_custom(func(a, b): return confusion[a] > confusion[b])
	for k in keys:
		res.note("  measured->derived %s: %d" % [k, confusion[k]])
	res.note("unsupported: %d of %d sites have a feature no VillageSpec can say" % [sites_with_gaps, measured.size()])
	var gk := gaps.keys()
	gk.sort_custom(func(a, b): return gaps[a] > gaps[b])
	for k in gk:
		res.note("  %s: %d" % [k, gaps[k]])
