extends RefCounted
## VTER-REALISM: generated villages against the real world set, per stratum
## (docs/VILLAGE_REALISM.md).
##
## A stratum is an environment the survey covers: flat lowland, steep
## hillside, valley, crest, coast, lake, island, arid, polar. A real site
## belongs to every stratum its record satisfies (`in_stratum`, on env and
## morph alone); the band of a (stratum, metric) cell is the real p10-p90 of
## the members. Generated villages are planned ON the world90 grid of a real
## site of that stratum (`SAMPLE`), measured with VillageShape (the GDScript
## twin of survey.py measure(); parity is tools/shape_parity.gd), and the cell
## takes the median over the plans that belong to the stratum.
##
## The gate is a baseline, not a target: tests/fixtures/settlements/
## realism_baseline.json holds, per cell, whether the generator was inside the
## band. The suite fails when a cell that was IN is now OUT, and when the
## baseline names a cell the suite no longer produces. Cells that are out stay
## out without failing; they are follow-up tasks, not a licence to widen a
## band. A control proves the comparison can fail.
##
## Refresh the baseline and the table in the doc after a deliberate change:
##   BRICK_WILD_REALISM_UPDATE=1 godot --headless --path . --script res://tests/run_all.gd -- vrealism

const WORLD_SET := "res://tests/fixtures/settlements/world_settlements.json"
const WORLD90 := "res://tests/fixtures/terrain/world90/"
const BASELINE := "res://tests/fixtures/settlements/realism_baseline.json"
const DOC := "res://docs/VILLAGE_REALISM.md"
const POPULATION := 50
const SEED := 4242
const MIN_REAL := 5              ## fewer real members than this: the cell is not judged
const TARGET_SHARE := 0.75       ## the acceptance bar, reported, not gated

const STRATA: Array[String] = ["lowland", "hillside", "valley", "crest", "coast", "lake", "island", "arid", "polar"]

## The survey metrics a 50-person plan can be asked. Left out: the counts that
## grow with the mapped disc (osm_buildings, body_buildings, body_hull_ha,
## body_offset_m, footprint_cv/p90 -- spread of a thousand OSM polygons),
## slope_p90 duplicates slope_median, and the percentage-of-disc keys the plan
## cannot have (adjacent_water_ha, road_reached, water_median_m).
const METRICS: Array[String] = [
	"body_share", "clark_evans", "nn_median_m", "elongation", "compactness", "coverage",
	"footprint_median_m2", "orientation_order", "dead_end_ratio", "intersections_per_ha",
	"road_km_per_ha", "frontage_aligned", "setback_median_m", "elev_span_m",
	"slope_median_pct", "body_elev_pctile", "water_within_30m", "over_water_share",
	"steps_ways", "bridges", "squares", "worship_centrality", "worship_elev_pctile",
]

## Real sites, one per plan; the stratum of each plan is read off its record.
const SAMPLE: Array[String] = [
	"Koshi", "Cayumba", "Monteriggioni", "Civita di Bagnoregio",
	"Posillipo", "Limone sul Garda", "Lelu", "Aoloau", "Bakel", "Zýgi",
	"Vijayapuri North", "Naujaat", "Haldenstein", "Tofta",
]

## Jobs measured once per (purpose, water): the programme depends on both.
static var _jobs := {}


static func run() -> SuiteResult:
	var res := SuiteResult.new("vrealism")
	var t0 := Time.get_ticks_msec()
	var sites := _real_sites()
	res.checked += 1
	if sites.size() < 100:
		res.fail("the world set reads %d usable sites, wants 100+" % sites.size())
		return res
	var ground := _ground_index()
	var cells := {}                      # stratum -> metric -> {"real": [..], "gen": [..]}
	for st in STRATA:
		cells[st] = {}
		for m in METRICS:
			cells[st][m] = {"real": [], "gen": []}
	for s in sites:
		for st in STRATA:
			if in_stratum(st, s):
				for m in METRICS:
					var v = s["morph"].get(m)
					if v != null:
						cells[st][m]["real"].append(float(v))
	var plans_by_stratum := {}
	for st in STRATA:
		plans_by_stratum[st] = []
	for name in SAMPLE:
		var site := _site(sites, name)
		res.checked += 1
		if site.is_empty() or not ground.has(name):
			res.fail("sample site %s is not in the set with a world90 grid" % name)
			continue
		var t1 := Time.get_ticks_msec()
		var plan := _plan(site, ground[name])
		var secs := (Time.get_ticks_msec() - t1) / 1000.0
		if plan == null or plan.buildings.is_empty():
			res.fail("%s: no plan on its own ground" % name)
			continue
		var shape := VillageShape.measure(plan)
		var member := []
		for st in STRATA:
			if in_stratum(st, site):
				member.append(st)
				plans_by_stratum[st].append(name)
				for m in METRICS:
					if shape.get(m) != null:
						cells[st][m]["gen"].append(float(shape[m]))
		res.note("%s: form %s, %d buildings, %.1f s, strata %s" % [name, plan.spec.form,
			plan.buildings.size(), secs, ",".join(member)])
	var table := judge(cells)
	_report(res, table, plans_by_stratum, sites.size())
	_gate(res, table)
	_control(res)
	if OS.get_environment("BRICK_WILD_REALISM_UPDATE") == "1":
		_update(res, table, plans_by_stratum, sites.size())
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


# ------------------------------------------------------------- strata

## Membership by env and morph alone (non-exclusive: a lake village on a hill
## is both). Thresholds are the survey's own: 8 % is its steep ground.
static func in_stratum(st: String, s: Dictionary) -> bool:
	var e: Dictionary = s["env"]
	var m: Dictionary = s["morph"]
	var slope := float(m["slope_median_pct"]) if m.get("slope_median_pct") != null else 0.0
	var relief := float(e["relief_disc_m"]) if e.get("relief_disc_m") != null else 0.0
	var pct := float(m["body_elev_pctile"]) if m.get("body_elev_pctile") != null else 0.5
	var label := String(s.get("spec", {}).get("label_form", ""))
	var koppen := String(e.get("koppen", "?"))
	match st:
		"lowland":
			return slope < 4.0 and relief < 60.0
		"hillside":
			return slope >= 8.0
		"valley":
			return label == "valley" or (pct < 0.25 and relief >= 100.0)
		"crest":
			return label == "crest" or (pct > 0.8 and relief >= 60.0)
		"coast":
			return bool(m.get("coast_in_disc", false)) or (e.get("coast_km") != null and float(e["coast_km"]) < 2.0)
		"lake":
			return e.get("lake_km") != null and float(e["lake_km"]) < 2.0
		"island":
			return e.get("landmass_km2") != null and float(e["landmass_km2"]) < 500.0
		"arid":
			return koppen.begins_with("B")
		"polar":
			return koppen.begins_with("E") or absf(float(s.get("lat", 0.0))) > 66.5
	return false


static func _real_sites() -> Array:
	var text := FileAccess.get_file_as_string(WORLD_SET)
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var out := []
	if not (data is Dictionary):
		return out
	for s in data.get("sites", []):
		if bool(s.get("morph", {}).get("usable", false)):
			out.append(s)
	return out


static func _site(sites: Array, name: String) -> Dictionary:
	for s in sites:
		if String(s["name"]) == name:
			return s
	return {}


static func _ground_index() -> Dictionary:
	var out := {}
	var idx: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORLD90 + "index.json"))
	if not (idx is Dictionary):
		return out
	for name in idx["sites"]:
		out[name] = WORLD90 + String(idx["sites"][name])
	return out


# ------------------------------------------------------------- planning

static func _plan(site: Dictionary, path: String) -> VillagePlan:
	var ground := VillageTerrain.from_file(path)
	if ground == null or not ground.valid():
		return null
	var water := "none"
	var env: Dictionary = site["env"]
	if in_stratum("lake", site) or FileAccess.get_file_as_string(path).contains("; lake:"):
		water = "lake"
	elif in_stratum("coast", site):
		water = "coast"
	var purpose := "farming" if water == "none" else "fishing"
	var key := purpose + "/" + water
	var spec := VillageSpec.new(SEED)
	spec.population = POPULATION
	spec.purpose = StringName(purpose)
	spec.water = StringName(water)
	spec.terrain = ground
	spec.generate(SEED)
	if not _jobs.has(key):
		var flat := VillageSpec.new(SEED)
		flat.population = POPULATION
		flat.purpose = StringName(purpose)
		flat.water = StringName(water)
		flat.generate(SEED)
		_jobs[key] = VillageLotPlanner.measure_all(VillageProgrammer.programme(flat))
	return VillageLotPlanner.plan_measured(spec, _jobs[key])


# ------------------------------------------------------------- judging

## cells -> {stratum: {metric: {n_real, n_gen, p10, p90, gen, state}}}; state
## is "in", "low", "high" or "na" (too few real members or no generated value).
static func judge(cells: Dictionary) -> Dictionary:
	var out := {}
	for st in cells:
		out[st] = {}
		for m in cells[st]:
			var real: Array = cells[st][m]["real"]
			var gen: Array = cells[st][m]["gen"]
			var row := {"n_real": real.size(), "n_gen": gen.size(), "p10": null, "p90": null, "gen": null, "state": "na"}
			if real.size() >= MIN_REAL:
				row["p10"] = _pct(real, 10.0)
				row["p90"] = _pct(real, 90.0)
			if not gen.is_empty():
				row["gen"] = _pct(gen, 50.0)
			if row["p10"] != null and row["gen"] != null:
				row["state"] = classify(float(row["gen"]), float(row["p10"]), float(row["p90"]))
			out[st][m] = row
	return out


static func classify(v: float, p10: float, p90: float) -> String:
	# a hair of slack: the bands are rounded to the fixture's decimals
	if v < p10 - 1e-9:
		return "low"
	if v > p90 + 1e-9:
		return "high"
	return "in"


static func _pct(values: Array, p: float) -> float:
	var v: Array = values.duplicate()
	v.sort()
	var k: float = (v.size() - 1) * p / 100.0
	var lo := int(floor(k))
	var hi := mini(lo + 1, v.size() - 1)
	return lerpf(v[lo], v[hi], k - lo)


static func cell_key(st: String, m: String) -> String:
	return st + "/" + m


## {key: true/false} for every judged cell.
static func states(table: Dictionary) -> Dictionary:
	var out := {}
	for st in table:
		for m in table[st]:
			var s: String = table[st][m]["state"]
			if s != "na":
				out[cell_key(st, m)] = (s == "in")
	return out


## Regressions: baseline cells that were in and are now out, and baseline
## cells that vanished.
static func regressions(baseline: Dictionary, now: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in baseline:
		if not now.has(k):
			out.append("%s: in the baseline, no longer judged" % k)
		elif bool(baseline[k]) and not bool(now[k]):
			out.append("%s: was inside the real p10-p90, now outside" % k)
	return out


static func _gate(res: SuiteResult, table: Dictionary) -> void:
	var now := states(table)
	res.checked += 1
	var text := FileAccess.get_file_as_string(BASELINE)
	var base: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not (base is Dictionary) or not base.has("cells"):
		if OS.get_environment("BRICK_WILD_REALISM_UPDATE") != "1":
			res.fail("no baseline at %s (run once with BRICK_WILD_REALISM_UPDATE=1)" % BASELINE)
		return
	if OS.get_environment("BRICK_WILD_REALISM_UPDATE") != "1":
		for line in regressions(base["cells"], now):
			res.fail(line)
	var n_in := 0
	for k in now:
		if now[k]:
			n_in += 1
	res.note("cells: %d judged, %d inside (%.0f %%), bar %.0f %%" % [now.size(), n_in,
		100.0 * n_in / maxi(1, now.size()), 100.0 * TARGET_SHARE])


## The gate must be able to fail: a baseline cell that was in, now out.
static func _control(res: SuiteResult) -> void:
	res.checked += 1
	var fake_cells := {"s": {"m": {"real": [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], "gen": [2.0]}}}
	var base_state := states(judge(fake_cells))
	fake_cells["s"]["m"]["gen"] = [99.0]
	var moved := states(judge(fake_cells))
	if base_state.get("s/m") != true or moved.get("s/m") != false:
		res.fail("control: the judge does not tell in from out")
	elif regressions(base_state, moved).size() != 1:
		res.fail("control: a cell leaving its band is not reported as a regression")
	elif not regressions(moved, base_state).is_empty():
		res.fail("control: a cell entering its band is reported as a regression")


# ------------------------------------------------------------- report

static func _fmt(v: Variant) -> String:
	if v == null:
		return "-"
	var f := float(v)
	return "%.0f" % f if absf(f) >= 100.0 else ("%.1f" % f if absf(f) >= 10.0 else "%.2f" % f)


static func summary_of(table: Dictionary) -> Dictionary:
	var per := {}
	var total_in := 0
	var total := 0
	for st in table:
		var n_in := 0
		var n := 0
		for m in table[st]:
			var s: String = table[st][m]["state"]
			if s == "na":
				continue
			n += 1
			if s == "in":
				n_in += 1
		per[st] = Vector2i(n_in, n)
		total_in += n_in
		total += n
	return {"per": per, "in": total_in, "n": total}


static func _report(res: SuiteResult, table: Dictionary, plans: Dictionary, n_real: int) -> void:
	var sm := summary_of(table)
	for st in STRATA:
		var v: Vector2i = sm["per"][st]
		res.note("%-9s %2d of %2d cells inside (%d plans: %s)" % [st, v.x, v.y, plans[st].size(), ", ".join(plans[st])])
	res.note("all strata: %d of %d cells inside (%.0f %%)" % [sm["in"], sm["n"], 100.0 * sm["in"] / maxi(1, sm["n"])])
	for st in STRATA:
		for m in METRICS:
			var r: Dictionary = table[st][m]
			if r["state"] == "low" or r["state"] == "high":
				res.note("OUT %s %s: generated %s, real p10-p90 %s-%s (%s)" % [st, m, _fmt(r["gen"]),
					_fmt(r["p10"]), _fmt(r["p90"]), r["state"]])


static func markdown(table: Dictionary, plans: Dictionary, n_real: int) -> String:
	var sm := summary_of(table)
	var out := "### In-band share by stratum\n\n| Stratum | Real sites (n) | Generated plans | Cells inside | Share |\n|---|---|---|---|---|\n"
	for st in STRATA:
		var v: Vector2i = sm["per"][st]
		var n_real_st := 0
		for m in METRICS:
			n_real_st = maxi(n_real_st, int(table[st][m]["n_real"]))
		out += "| %s | %d | %d (%s) | %d of %d | %.0f %% |\n" % [st, n_real_st, plans[st].size(),
			", ".join(plans[st]), v.x, v.y, 100.0 * v.x / maxi(1, v.y)]
	out += "| **all** | %d | | %d of %d | **%.0f %%** |\n\n" % [n_real, sm["in"], sm["n"], 100.0 * sm["in"] / maxi(1, sm["n"])]
	out += "### Every cell\n\nEach cell: generated median (real p10-p90, in/LOW/HIGH). `-` : fewer than %d real members or no generated value.\n\n" % MIN_REAL
	out += "| Metric | " + " | ".join(STRATA) + " |\n|---|" + "---|".repeat(STRATA.size()) + "\n"
	for m in METRICS:
		var row := "| `%s` |" % m
		for st in STRATA:
			var r: Dictionary = table[st][m]
			if r["state"] == "na":
				row += " - |"
			else:
				var tag: String = "in" if r["state"] == "in" else r["state"].to_upper()
				row += " %s (%s-%s) %s |" % [_fmt(r["gen"]), _fmt(r["p10"]), _fmt(r["p90"]), tag if r["state"] != "in" else "in"]
		out += row + "\n"
	return out


static func _update(res: SuiteResult, table: Dictionary, plans: Dictionary, n_real: int) -> void:
	var cells := states(table)
	var f := FileAccess.open(BASELINE, FileAccess.WRITE)
	if f == null:
		res.fail("cannot write %s" % BASELINE)
		return
	var keys := cells.keys()
	keys.sort()
	var sorted := {}
	for k in keys:
		sorted[k] = cells[k]
	f.store_string(JSON.stringify({"about": "VTER-REALISM baseline: true = the generated median was inside the real p10-p90 of the stratum. The vrealism suite fails when a true becomes false.",
		"cells": sorted}, "  ", true) + "\n")
	f.close()
	var doc := FileAccess.get_file_as_string(DOC)
	var a := doc.find("<!-- realism:begin -->")
	var b := doc.find("<!-- realism:end -->")
	if a >= 0 and b > a:
		doc = doc.substr(0, a) + "<!-- realism:begin -->\n" + markdown(table, plans, n_real) + doc.substr(b)
		var g := FileAccess.open(DOC, FileAccess.WRITE)
		g.store_string(doc)
		g.close()
	res.note("baseline and doc table rewritten")
