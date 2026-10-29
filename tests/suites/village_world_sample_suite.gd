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
##   3. every measured site with real ground (tests/fixtures/terrain/world90,
##      written by survey.py terrain-world) builds its spec WITH that ground,
##      and the form the ground derives (VillageSpec.form_intent) must agree
##      with the hand label at least MIN_INTENT_AGREE_HM of the time over the
##      high and medium confidence labels. That one IS a failure.

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
## The owner's vocabulary (VILLAGE_TERRAIN.md, Decisions) is twelve forms and
## the fitted classifier uses eleven of them (`gate` needs a manor no measure
## sees); the old six-form floor would pass a classifier that never said
## hillside, shore, crest, valley or water. Nine keeps the new names in.
const MIN_FORMS := 9          # distinct nearest_form values
## Hand labels (tools/settlements/form_labels.json), copied into spec.label_form.
const MIN_LABELLED := 100     # measured sites carrying a label_form
## The spec's old `strand` is the owner's `shore` (the vocabulary folded it in).
const FORM_ALIAS := {"strand": "shore"}
## Real 90 m ground for each measured site; index.json maps name -> grid.
const WORLD90 := "res://tests/fixtures/terrain/world90/"
## A grid's `about` says "; lake:" when survey.py read the site as a lake
## shore (>= 15 ha of adjacent water, not coastal): its spec water is `lake`.
const LAKE_MARK := "; lake:"
## The terrain form rule (VillageSpec._derive_form_on_ground) agreed with
## 48 of 84 high/medium labels (57 %) when it was fitted (VTER-FORM-DERIVE,
## 2026-10-16; the flat rule: 1 of 84). Every threshold moved +-20 % alone
## kept it at 54-57 %. The floor sits a few points under: a change that
## costs four or more correct forms fails here and must say why.
const MIN_INTENT_AGREE_HM := 0.52


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

	var ground := _world_ground(res)
	_coverage(res, sites, measured, ground)
	_specs(res, measured)
	_intents(res, measured, ground)
	_economy_stands_back(res)
	_place_targets(res, sites)
	return res


## VTER-REAL-WATERFRONT (owner decision 2026-10-28): a farming village stands
## back from the water; only a fishing economy takes the shore or water form.
## The control is the same ground read with the economy changed.
static func _economy_stands_back(res: SuiteResult) -> void:
	var wet := {"wet_share": 0.6, "wide_wet_share": 0.6, "centre_tpi": 0.0, "centre_rank": 0.5,
		"water_far_m": 10.0, "slope_p75": 0.05, "slope_median": 0.03, "level_regions": 1}
	var shore := {"wet_share": 0.1, "wide_wet_share": 0.1, "centre_tpi": 0.0, "centre_rank": 0.5,
		"water_far_m": 120.0, "slope_p75": 0.05, "slope_median": 0.03, "level_regions": 1}
	for purpose in [&"farming", &"forest"]:
		for g in [wet, shore]:
			res.checked += 1
			var f := VillageSpec._derive_form_on_ground(g, 60, purpose, &"coast", &"english")
			if f in [&"shore", &"water"]:
				res.fail("a %s village on wet ground took the %s form; it stands back from the water" % [purpose, f])
	res.checked += 2
	if VillageSpec._derive_form_on_ground(wet, 60, &"fishing", &"coast", &"english") != &"shore":
		res.fail("control: a fishing village on a drowned window must take the shore form")
	if VillageSpec._derive_form_on_ground(shore, 60, &"fishing", &"coast", &"english") != &"shore":
		res.fail("control: a fishing coast village with water 120 m off must take the shore form")


## VTER-PLACE: the targets VillagePlaceCheck reads from the
## world set are still the world set's -- numpy's linear percentiles of each
## metric over the sites that have it, to the third decimal.
const PLACE_TOL := 0.0015


static func _place_targets(res: SuiteResult, sites: Array) -> void:
	for row in [["worship_elev_pctile", VillagePlaceCheck.WORLD_WORSHIP_ELEV_IQR],
			["worship_centrality", VillagePlaceCheck.WORLD_WORSHIP_CENTRALITY_IQR],
			["body_elev_pctile", VillagePlaceCheck.WORLD_BODY_ELEV_IQR],
			["water_within_30m", VillagePlaceCheck.WORLD_WATERFRONT_IQR]]:
		var vals := PackedFloat64Array()
		for site in sites:
			var v = site["morph"].get(row[0])
			if v != null and typeof(v) in [TYPE_FLOAT, TYPE_INT]:
				vals.append(float(v))
		vals.sort()
		var iqr := Vector2(_percentile(vals, 25.0), _percentile(vals, 75.0))
		res.checked += 1
		var want: Vector2 = row[1]
		if absf(iqr.x - want.x) > PLACE_TOL or absf(iqr.y - want.y) > PLACE_TOL:
			res.fail("place targets: %s IQR is %.3f-%.3f over %d sites, VillagePlaceCheck says %.3f-%.3f"
				% [row[0], iqr.x, iqr.y, vals.size(), want.x, want.y])
		if row[0] == "worship_elev_pctile":
			res.checked += 1
			var med := _percentile(vals, 50.0)
			if absf(med - VillagePlaceCheck.WORLD_WORSHIP_ELEV_MEDIAN) > PLACE_TOL:
				res.fail("place targets: worship_elev_pctile median is %.3f, VillagePlaceCheck says %.3f"
					% [med, VillagePlaceCheck.WORLD_WORSHIP_ELEV_MEDIAN])
		res.note("place target %s: IQR %.3f-%.3f over %d sites" % [row[0], iqr.x, iqr.y, vals.size()])


## numpy.percentile's default (linear) over a sorted array.
static func _percentile(sorted: PackedFloat64Array, q: float) -> float:
	if sorted.is_empty():
		return NAN
	var r: float = q / 100.0 * (sorted.size() - 1)
	var i := int(floor(r))
	var j := mini(i + 1, sorted.size() - 1)
	return lerpf(sorted[i], sorted[j], r - i)


## name -> {"path", "lake"} for every world90 grid the index lists.
static func _world_ground(res: SuiteResult) -> Dictionary:
	var out := {}
	res.checked += 1
	var text := FileAccess.get_file_as_string(WORLD90 + "index.json")
	var idx = JSON.parse_string(text) if not text.is_empty() else null
	if typeof(idx) != TYPE_DICTIONARY or not idx.has("sites"):
		res.fail("cannot read %sindex.json (survey.py terrain-world writes it)" % WORLD90)
		return out
	for name in idx["sites"]:
		var path: String = WORLD90 + String(idx["sites"][name])
		var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(doc) != TYPE_DICTIONARY:
			res.fail("world90 grid %s is unreadable" % path)
			continue
		out[name] = {"path": path, "lake": String(doc.get("about", "")).contains(LAKE_MARK)}
	return out


## The spec water a site has WITH its ground: the fixture's, or `lake`.
static func _water_with_ground(s: Dictionary, ground: Dictionary) -> String:
	var g: Dictionary = ground.get(s["name"], {})
	return "lake" if bool(g.get("lake", false)) else String(s["spec"]["water"])


static func _count(rows: Array, pred: Callable) -> int:
	var n := 0
	for r in rows:
		if pred.call(r):
			n += 1
	return n


static func _coverage(res: SuiteResult, sites: Array, measured: Array, ground: Dictionary) -> void:
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
		water[_water_with_ground(s, ground)] = true
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
	var labelled := 0
	var near_agree := 0
	var near_agree_hm := 0
	var labelled_hm := 0
	var derived_agree := 0
	var derived_agree_hm := 0
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
		if m.has("label_form"):
			var label := String(m["label_form"])
			var firm: bool = String(m.get("label_confidence", "low")) != "low"
			var derived_v := String(FORM_ALIAS.get(derived, derived))
			labelled += 1
			near_agree += int(real == label)
			derived_agree += int(derived_v == label)
			if firm:
				labelled_hm += 1
				near_agree_hm += int(real == label)
				derived_agree_hm += int(derived_v == label)
		var key := "%s->%s" % [real, derived]
		confusion[key] = int(confusion.get(key, 0)) + 1
		var unsupported: Array = m["unsupported"]
		if not unsupported.is_empty():
			sites_with_gaps += 1
		for g in unsupported:
			var tag := String(g).get_slice(":", 0)
			gaps[tag] = int(gaps.get(tag, 0)) + 1
	res.checked += 1
	if labelled < MIN_LABELLED:
		res.fail("only %d measured sites carry a label_form, the set needs %d" % [labelled, MIN_LABELLED])
	else:
		res.note("labels: nearest_form (the survey's classifier) matches label_form for %d of %d labelled sites, %d of %d at high or medium confidence"
			% [near_agree, labelled, near_agree_hm, labelled_hm])
		res.note("labels: the spec-derived VillageSpec.form (strand read as shore) matches label_form for %d of %d labelled sites, %d of %d at high or medium confidence"
			% [derived_agree, labelled, derived_agree_hm, labelled_hm])
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


## The form each measured site's own ground derives, against its hand label.
static func _intents(res: SuiteResult, measured: Array, ground: Dictionary) -> void:
	var with_ground := 0
	var agree := 0
	var labelled := 0
	var agree_hm := 0
	var labelled_hm := 0
	var confusion := {}
	var intents := {}
	var valley_sites: Array[String] = []
	for i in range(measured.size()):
		var s: Dictionary = measured[i]
		if not ground.has(s["name"]):
			continue
		var m: Dictionary = s["spec"]
		var spec := VillageSpec.new(9000 + i)
		spec.population = int(m["population"])
		spec.culture = StringName(m["culture"])
		spec.purpose = StringName(m["purpose"])
		spec.water = StringName(_water_with_ground(s, ground))
		spec.enclosure = StringName(m["enclosure"])
		spec.terrain = VillageTerrain.from_file(ground[s["name"]]["path"])
		res.checked += 1
		if not spec.valid():
			res.fail("%s with its ground maps to an invalid spec: %s" % [s["name"], "; ".join(spec.errors())])
			continue
		spec.generate(9000 + i)
		with_ground += 1
		var intent := String(spec.form_intent)
		intents[intent] = int(intents.get(intent, 0)) + 1
		if intent == "valley":
			valley_sites.append("%s (label %s, water %s)" % [s["name"], m.get("label_form", "-"), spec.water])
		res.checked += 1
		if not (spec.form_intent in VillageSpec.FORM_VOCABULARY) or not (spec.form in VillageSitePlanner.FORMS_SUPPORTED):
			res.fail("%s: intent '%s' planned as '%s', outside the vocabulary or the planners"
				% [s["name"], intent, spec.form])
		res.checked += 1
		if spec.form != VillageSpec.FORM_FALLBACK.get(spec.form_intent, spec.form_intent):
			res.fail("%s: intent '%s' planned as '%s', not its FORM_FALLBACK" % [s["name"], intent, spec.form])
		if not m.has("label_form"):
			continue
		var label := String(m["label_form"])
		labelled += 1
		agree += int(intent == label)
		if String(m.get("label_confidence", "low")) != "low":
			labelled_hm += 1
			agree_hm += int(intent == label)
			var key := "%s->%s" % [label, intent]
			confusion[key] = int(confusion.get(key, 0)) + 1
	res.checked += 1
	if with_ground < MIN_MEASURED:
		res.fail("only %d measured sites have world90 ground, the set needs %d" % [with_ground, MIN_MEASURED])
	var share := float(agree_hm) / maxi(1, labelled_hm)
	res.checked += 1
	if share < MIN_INTENT_AGREE_HM:
		res.fail("the ground-derived form_intent matches label_form for %d of %d high/medium labels (%.0f %%), under the %.0f %% floor"
			% [agree_hm, labelled_hm, share * 100.0, MIN_INTENT_AGREE_HM * 100.0])
	res.note("ground: %d measured sites specified on their world90 ground; form_intent matches label_form for %d of %d labelled, %d of %d (%.0f %%) at high or medium confidence"
		% [with_ground, agree, labelled, agree_hm, labelled_hm, share * 100.0])
	var ik := intents.keys()
	ik.sort()
	res.note("  form_intent counts: %s" % ", ".join(ik.map(func(k): return "%s %d" % [k, intents[k]])))
	res.note("  derive valley: %s" % ", ".join(valley_sites))
	var keys := confusion.keys()
	keys.sort_custom(func(a, b): return confusion[a] > confusion[b] or (confusion[a] == confusion[b] and a < b))
	for k in keys:
		res.note("  label->intent (high/medium) %s: %d" % [k, confusion[k]])
