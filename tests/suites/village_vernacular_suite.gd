extends RefCounted
## VILLAGE-VERNACULAR (`vvernacular`; docs/VILLAGE_VERNACULAR.md): the regional
## dataset reads and validates, a look travels and is refused where it must
## be, an empty look moves nothing, each region's village keeps its signature,
## a blend shows both its parents, wealth shows, and the controls fail -- a
## plain Mediterranean village is not Cycladic, a Norse village is not Cycladic,
## and a Cycladic programme whose looks never reach the generator is caught.
##
## Programme-level: every dwelling is GENERATED (placement path, no furniture)
## and measured, but no village is laid out. `vvernacularbuild` builds every
## house type and shop and runs BrickWild.check on it.

const POP := 40
const SEED := 3
const FIXTURES := {
	&"provence": &"market", &"cyclades": &"fishing", &"norse": &"farming", &"japanese": &"farming",
}


static func run() -> SuiteResult:
	var res := SuiteResult.new("vvernacular")
	var t0 := Time.get_ticks_msec()
	_dataset(res)
	_transport(res)
	_moves_nothing(res)
	var measured := _regions(res)
	_blends(res)
	_wealth(res)
	_controls(res, measured)
	_village_parts(res)
	_ground_character(res)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func _spec(v: Dictionary, purpose: StringName = &"farming", wealth := 0.5,
		pop := POP, p_seed := SEED) -> VillageSpec:
	var spec := VillageSpec.new(p_seed)
	spec.population = pop
	spec.purpose = purpose
	spec.wealth = wealth
	spec.vernacular = v
	spec.generate(p_seed)
	return spec


# ------------------------------------------------------------ the dataset

static func _dataset(res: SuiteResult) -> void:
	var ids := VillageVernacular.region_ids()
	res.checked += 1
	for want in [&"provence", &"cyclades", &"norse", &"japanese"]:
		if not want in ids:
			res.fail("dataset: no region '%s' (have %s)" % [want, str(ids)])
	for id in ids:
		res.checked += 1
		var errs := VillageVernacular.region_errors(VillageVernacular.region(id))
		if not errs.is_empty():
			res.fail("dataset: %s has errors %s" % [id, str(errs)])
	res.checked += 1
	if VillageVernacular.resolve_id(&"greek") != &"cyclades" or VillageVernacular.resolve_id(&"Viking") != &"norse":
		res.fail("dataset: aliases do not resolve (greek -> %s, viking -> %s)" % [
			VillageVernacular.resolve_id(&"greek"), VillageVernacular.resolve_id(&"Viking")])
	# control: a broken row is refused, and says why
	var broken: Dictionary = VillageVernacular.region(&"cyclades").duplicate(true)
	broken["houses"]["cube"]["style"] = "pagoda"
	broken["roofs"]["flat lime"]["types"] = {"dome": 1.0}
	broken["walls"][0]["hex"] = ["zzzzzz", "ffffff"]
	broken["houses"]["captain's house"]["look"]["engawa"] = 1.0
	var why := VillageVernacular.region_errors(broken)
	res.checked += 1
	if why.size() < 4:
		res.fail("control: a broken region drew only %d complaints: %s" % [why.size(), str(why)])
	# a fantasy people, registered for the run
	var elven: Dictionary = VillageVernacular.region(&"norse").duplicate(true)
	elven["label"] = "Elven glade"
	elven["walls"] = [{"name": "moon white", "w": 1.0, "hex": ["e8ecf2", "d8dee8"]}]
	var errs2 := VillageVernacular.register(&"elven", elven)
	res.checked += 1
	if not errs2.is_empty() or not &"elven" in VillageVernacular.region_ids() \
			or not (VillageVernacular.parse({"elven": 0.5, "norse": 0.5})["errors"] as Array).is_empty():
		res.fail("register: a custom region was not taken (%s)" % str(errs2))
	VillageVernacular.unregister(&"elven")
	res.checked += 1
	if &"elven" in VillageVernacular.region_ids():
		res.fail("register: unregister left the region behind")
	res.note("dataset: %d regions %s; the broken control drew %d complaints" % [ids.size(), str(ids), why.size()])


# ------------------------------------------------------------ the request

static func _transport(res: SuiteResult) -> void:
	var house := BuildingRequest.house(41, &"mediterranean", &"none", 8.0, 10.0, 2.6, 1)
	house.look = {"wall": ["f7f6f1", "ecebe4"], "roof_types": [&"flat"], "roof_pitch": [0.0, 0.0],
		"parapet": 1.0, "roof_material": &"earth"}
	var back := BuildingRequest.from_json(house.to_json())
	res.checked += 1
	if back.to_dict() != house.to_dict() or back.look.is_empty():
		res.fail("transport: a look did not survive JSON (%s vs %s)" % [str(back.to_dict()), str(house.to_dict())])
	var plain := BuildingRequest.house(41, &"mediterranean")
	res.checked += 1
	if plain.to_dict().has("look") or plain.to_dict().has("vernacular"):
		res.fail("transport: an empty look or vernacular is written into the request document")
	var village := BuildingRequest.village(5, 40)
	village.vernacular = {"blend": {"provence": 0.7, "norse": 0.3}, "coherence": 0.5}
	res.checked += 1
	if BuildingRequest.from_json(village.to_json()).to_dict() != village.to_dict():
		res.fail("transport: a vernacular did not survive JSON")
	res.checked += 1
	if not BuildingLibrary.validate(house).is_empty() or not BuildingLibrary.validate(village).is_empty():
		res.fail("validate: good requests refused %s %s" % [str(BuildingLibrary.validate(house)), str(BuildingLibrary.validate(village))])
	# refusals
	var cases := []
	var bad_key := BuildingRequest.house(41, &"cottage")
	bad_key.look = {"parapet": 1.0}                   # a cottage has no parapet to change
	cases.append([bad_key, &"invalid_look"])
	var bad_roof := BuildingRequest.house(41, &"asian")
	bad_roof.look = {"roof_types": [&"flat"]}          # a minka builds its own roof
	cases.append([bad_roof, &"invalid_look"])
	var temple := BuildingRequest.temple(41)
	temple.look = {"wall": "ffffff"}
	cases.append([temple, &"unsupported_option"])
	var church := BuildingRequest.church(41)
	church.look = {"roof_types": [&"flat"]}            # a church takes colours only
	cases.append([church, &"invalid_look"])
	var on_house := BuildingRequest.house(41)
	on_house.vernacular = {"norse": 1.0}
	cases.append([on_house, &"unsupported_option"])
	var unknown := BuildingRequest.village(5, 40)
	unknown.vernacular = {"atlantis": 1.0}
	cases.append([unknown, &"invalid_vernacular"])
	for c in cases:
		res.checked += 1
		var codes := BuildingLibrary.validate(c[0]).map(func(e): return e["code"])
		if not c[1] in codes:
			res.fail("validate: %s with look %s / vernacular %s gave %s, not %s" % [
				c[0].kind, str(c[0].look), str(c[0].vernacular), str(codes), c[1]])


# ------------------------------------------------------------ moves nothing

## An empty look is the style row itself; a colour-only look changes the
## colours and not one other draw.
static func _moves_nothing(res: SuiteResult) -> void:
	for style in HouseSpec.STYLES:
		res.checked += 1
		if HouseSpec.patched_row(style, {}) != HouseSpec.STYLES[style]:
			res.fail("moves nothing: the empty look changed the %s row" % style)
	var a := HouseSpec.new()
	a.style = &"cottage"
	HouseGenerator.generate(a, 77, false)
	var b := HouseSpec.new()
	b.style = &"cottage"
	b.look = {"wall": "8e3024", "trim": "efebe1", "roof": "607b3b"}
	HouseGenerator.generate(b, 77, false)
	res.checked += 1
	var same := a.roof_pitch == b.roof_pitch and a.roof_type == b.roof_type and a.porch == b.porch \
		and a.chimney == b.chimney and a.timber_frame == b.timber_frame and a.room_count == b.room_count \
		and a.variant_name == b.variant_name and a.stud_pitch == b.stud_pitch
	if not same:
		res.fail("moves nothing: a colour-only look moved another draw")
	res.checked += 1
	if b.wall_color.to_html(false) != "8e3024" or b.roof_color.to_html(false) != "607b3b":
		res.fail("look: the colours were not honoured (wall #%s roof #%s)" % [
			b.wall_color.to_html(false), b.roof_color.to_html(false)])


# ------------------------------------------------------------ the regions

static func _regions(res: SuiteResult) -> Dictionary:
	var out := {}
	for id in FIXTURES:
		var t0 := Time.get_ticks_msec()
		var spec := _spec({String(id): 1.0}, FIXTURES[id])
		var measured := VillageVernacularCheck.measure_requests(VillageProgrammer.programme(spec))
		out[id] = measured
		var rep := VillageVernacularCheck.new().check(measured, spec.feature_set())
		res.checked += 1
		for f in rep["failures"]:
			res.fail("%s: %s" % [id, f])
		var line := ""
		var sig: Dictionary = rep["stats"].get("signature", {})
		for k in sig:
			var v: Variant = sig[k]["value"]
			line += "%s=%s " % [k, ("%.2f" % v) if v is float else str(v)]
		res.note("%-9s %-18s %2d dwellings | %s| %.0f s" % [id, spec.variant_name,
			measured["dwellings"].size(), line, (Time.get_ticks_msec() - t0) / 1000.0])
	return out


# ------------------------------------------------------------ blends

static func _blends(res: SuiteResult) -> void:
	# half Norse, half Japanese: both show, neither's signature is asked
	var spec := _spec({"norse": 0.5, "japanese": 0.5})
	var measured := VillageVernacularCheck.measure_requests(VillageProgrammer.programme(spec))
	var check := VillageVernacularCheck.new()
	var rep := check.check(measured, spec.feature_set())
	res.checked += 1
	for f in rep["failures"]:
		res.fail("blend norse+japanese: %s" % f)
	var mats := {}
	for row in measured["dwellings"]:
		mats[String(row["roof_material"])] = true
	res.checked += 1
	if not (mats.has("earth") or mats.has("shingle")) or not (mats.has("tile") or mats.has("thatch")):
		res.fail("blend norse+japanese: the roofs are not both peoples' (%s)" % str(mats.keys()))
	res.note("blend norse+japanese: %d dwellings, roofs %s, %s" % [measured["dwellings"].size(),
		str(mats.keys()), "ok" if rep["ok"] else "FAILS"])
	# Cycladic houses under Japanese roofing: a mediterranean chassis cannot build
	# an irimoya, so it keeps its own forms and takes the material and colour
	var over := _spec({"blend": {"cyclades": 1.0}, "groups": {"roofs": {"japanese": 1.0}}})
	var m2 := VillageVernacularCheck.measure_requests(VillageProgrammer.programme(over))
	var rep2 := VillageVernacularCheck.new().check(m2, over.feature_set())
	res.checked += 1
	for f in rep2["failures"]:
		res.fail("cyclades with japanese roofs: %s" % f)
	res.checked += 1
	for row in m2["dwellings"]:
		if not String(row["roof_material"]) in ["tile", "thatch"]:
			res.fail("cyclades with japanese roofs: a %s roof" % row["roof_material"])
			break
	res.checked += 1
	if over.feature_set().is_pure():
		res.fail("is_pure: a blend with another region's roofs called itself pure")
	# coherence: 1.0 is every group from one region; 0 mixes them
	var fs1 := VillageVernacular.resolve({"blend": {"provence": 0.5, "norse": 0.5}, "coherence": 1.0})
	var fs0 := VillageVernacular.resolve({"provence": 0.5, "norse": 0.5})
	var mixed1 := 0
	var mixed0 := 0
	for i in range(300):
		mixed1 += int(_mixed(fs1.house("coh|%d" % i, &"middle")))
		mixed0 += int(_mixed(fs0.house("coh|%d" % i, &"middle")))
	res.checked += 1
	if mixed1 != 0 or mixed0 < 150:
		res.fail("coherence: 1.0 mixed %d of 300 houses (wants 0), 0.0 mixed %d (wants most)" % [mixed1, mixed0])


static func _mixed(g: Dictionary) -> bool:
	var parents: Dictionary = g["parents"]
	var first: StringName = parents[&"houses"]
	for k in parents:
		if parents[k] != first:
			return true
	return false


# ------------------------------------------------------------ wealth

static func _wealth(res: SuiteResult) -> void:
	for id in FIXTURES:
		var fs := VillageVernacular.resolve({String(id): 1.0})
		var lo := fs.tier_shares(0.1)
		var hi := fs.tier_shares(0.9)
		res.checked += 1
		if not (float(hi[&"rich"]) > float(lo[&"rich"]) and float(hi[&"poor"]) < float(lo[&"poor"])):
			res.fail("wealth %s: tiers do not follow wealth (0.1 %s, 0.9 %s)" % [id, str(lo), str(hi)])
		var rich := 0.0
		var poor := 0.0
		for i in range(200):
			rich += float(fs.house("w|%d" % i, &"rich")["area"])
			poor += float(fs.house("w|%d" % i, &"poor")["area"])
		res.checked += 1
		if rich <= poor:
			res.fail("wealth %s: a rich house is no bigger than a poor one (%.2f vs %.2f)" % [id, rich / 200.0, poor / 200.0])
	var fs := VillageVernacular.resolve({"provence": 1.0})
	var areas: Array[float] = []
	for i in range(20):
		areas.append(60.0 + 5.0 * i)
	var count_rich := func(w: float) -> int:
		return fs.tiers_by_area(areas, w).count(&"rich")
	res.checked += 1
	if count_rich.call(0.9) <= count_rich.call(0.1):
		res.fail("wealth: a rich village has no more rich households (%d vs %d)" % [count_rich.call(0.9), count_rich.call(0.1)])
	var tiers := fs.tiers_by_area(areas, 0.5)
	res.checked += 1
	if tiers[19] != &"rich" or tiers[0] != &"poor":
		res.fail("wealth: the biggest house is not rich or the smallest not poor (%s)" % str(tiers))


# ------------------------------------------------------------ controls

static func _controls(res: SuiteResult, measured: Dictionary) -> void:
	var cyclades := VillageVernacular.resolve({"cyclades": 1.0})
	# 1. the culture alone, with no vernacular, is not a Cycladic village
	var plain := VillageSpec.new(SEED)
	plain.population = POP
	plain.purpose = &"fishing"
	plain.culture = &"mediterranean"
	plain.generate(SEED)
	var reqs := VillageProgrammer.programme(plain)
	res.checked += 1
	for r in reqs:
		if not r.look.is_empty():
			res.fail("control: a village with no vernacular carries a look")
			break
	var rep := VillageVernacularCheck.new().check(VillageVernacularCheck.measure_requests(reqs), cyclades)
	res.checked += 1
	if rep["ok"]:
		res.fail("control: a plain mediterranean village passed as Cycladic")
	res.note("control plain mediterranean as cyclades (must fail): %d complaints, e.g. %s" % [
		rep["failures"].size(), str(rep["failures"].slice(0, 2))])
	# 2. a Norse village is not a Cycladic one
	var rep2 := VillageVernacularCheck.new().check(measured[&"norse"], cyclades)
	res.checked += 1
	if rep2["ok"]:
		res.fail("control: a Norse village passed as Cycladic")
	# 3. looks that never reach the generator: the same Cycladic programme with
	#    every look stripped must fail -- the check measures the house, not the
	#    request
	var spec := _spec({"cyclades": 1.0}, &"fishing")
	var stripped := VillageProgrammer.programme(spec)
	for r in stripped:
		r.look = {}
	var rep3 := VillageVernacularCheck.new().check(VillageVernacularCheck.measure_requests(stripped), spec.feature_set())
	res.checked += 1
	if rep3["ok"]:
		res.fail("control: a Cycladic programme with no looks passed its own check")
	res.note("control looks stripped (must fail): %d complaints" % rep3["failures"].size())
	# 4. determinism
	res.checked += 1
	var again := VillageProgrammer.programme(_spec({"cyclades": 1.0}, &"fishing"))
	var first := VillageProgrammer.programme(spec)
	for i in range(first.size()):
		if first[i].to_dict() != again[i].to_dict():
			res.fail("determinism: request %d differs between two runs" % i)
			break


# ------------------------------------------------------------ real ground

## A vernacular names the buildings, so a real site's character (Manarola's
## three storeys) does not reach them; the same ground with no vernacular
## keeps it. Found by the walk bake of 15 Nov: a Cycladic village on
## Manarola's cliffs came out nine of eleven dwellings at three storeys.
static func _ground_character(res: SuiteResult) -> void:
	var path := "res://tests/fixtures/terrain/real30/manarola.json"
	var ground := VillageCharacterCheck.apply(VillageTerrain.from_file(path), "manarola")
	res.checked += 1
	if not ground.valid() or int(ground.character.get("storeys_min", 0)) < 3:
		res.fail("ground: the Manarola fixture no longer carries its three storeys (%s)" % str(ground.character))
		return
	var tall := func(v: Dictionary) -> Array:
		var spec := VillageSpec.new(4)
		spec.population = POP
		spec.purpose = &"fishing"
		spec.terrain = ground
		spec.vernacular = v
		spec.generate(4)
		var n := 0
		var three := 0
		for r in VillageProgrammer.programme(spec):
			if r.kind in [&"house", &"shop"]:
				n += 1
				three += int(r.storeys >= 3)
		return [three, n]
	var vern: Array = tall.call({"cyclades": 1.0})
	res.checked += 1
	if int(vern[0]) > 0:
		res.fail("ground: on Manarola's ground %d of %d Cycladic dwellings took the site's three storeys" % vern)
	var plain: Array = tall.call({})
	res.checked += 1
	if int(plain[0]) == 0:
		res.fail("control: on Manarola's ground a plain village lost the site's three storeys (%d of %d)" % plain)
	res.note("ground: Manarola, cyclades %d of %d dwellings at three storeys; plain %d of %d (control)" % [
		vern[0], vern[1], plain[0], plain[1]])


# ------------------------------------------------------------ the rest of it

static func _village_parts(res: SuiteResult) -> void:
	var spec := _spec({"norse": 0.5, "japanese": 0.5})
	var fs := spec.feature_set()
	var palette := VillageDressCatalog.palette_of(spec)
	res.checked += 1
	if palette != fs.plant_palette() or not "Wild_Pine_*" in palette.get("edge", []) \
			or not "Nature_MapleTree_*" in palette.get("edge", []):
		res.fail("plants: the blend's palette is not both peoples' (%s)" % str(palette.get("edge", [])))
	var ground: Array = BuildingFamilyAdapter.colours(_spec({"cyclades": 1.0}))
	res.checked += 1
	var want_road := String(VillageVernacular.region(&"cyclades")["ground"]["road"])
	if ground[VillageBuilder.SURF_ROAD].to_html(false) != want_road:
		res.fail("ground: the Cycladic road is #%s, not the dataset's #%s" % [
			ground[VillageBuilder.SURF_ROAD].to_html(false), want_road])
	var plain := VillageSpec.new(SEED)
	plain.population = POP
	plain.generate(SEED)
	res.checked += 1
	if BuildingFamilyAdapter.colours(plain)[VillageBuilder.SURF_ROAD].to_html(false) != VillageBuilder.COLOURS[VillageBuilder.SURF_ROAD]:
		res.fail("ground: a village with no vernacular changed its road colour")
	res.checked += 1
	if spec.variant_name.is_empty() or spec.variant_name == plain.variant_name:
		res.fail("names: the vernacular village has no name of its own (%s)" % spec.variant_name)
	res.checked += 1
	if spec.effective_culture() != &"east_asian" and spec.effective_culture() != &"norse":
		res.fail("culture: a norse/japanese blend stands for %s" % spec.effective_culture())
