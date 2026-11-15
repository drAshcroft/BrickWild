extends RefCounted
## VILLAGE-VERNACULAR (`vvernacularbuild`): every house type of every region in
## the dataset, and every region's shop, is built through the public path and
## passes BrickWild.check (HouseQA: shell, components, vernacular pieces,
## openings, navigation). A type that a style cannot build is found here, before
## any village draws it. Two seeds a type, so both ends of a draw are seen.

const SEEDS := [0, 1]
const BUSINESSES: Array[StringName] = [&"blacksmith", &"tavern"]


static func run() -> SuiteResult:
	var res := SuiteResult.new("vvernacularbuild")
	var t0 := Time.get_ticks_msec()
	var only := OS.get_environment("VERNACULAR_REGION")
	for id in VillageVernacular.region_ids():
		if not only.is_empty() and String(id) != only:
			continue
		var row := VillageVernacular.region(id)
		for type_id in row["houses"]:
			for k in SEEDS:
				var g := VillageVernacular.house_of_type(id, type_id, "build|%d" % k)
				var dims := VillageProgrammer.house_dims(g["style"], 85.0 * float(g["area"]), 2000 + k)
				var req := BuildingRequest.house(2000 + k, g["style"], &"none", dims.x, dims.y, 2.6, int(g["storeys"]))
				req.look = g["look"]
				_build(res, "%s %s #%d" % [id, type_id, k], req)
		var fs := VillageVernacular.resolve({String(id): 1.0})
		for i in range(BUSINESSES.size()):
			var g := fs.shop("build|%d" % i)
			var req := BuildingRequest.shop(3000 + i, BUSINESSES[i], g["style"], 7.5, 10.0, 2.8, int(g["storeys"]))
			req.look = g["look"]
			_build(res, "%s shop %s" % [id, BUSINESSES[i]], req)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func _build(res: SuiteResult, label: String, req: BuildingRequest) -> void:
	res.checked += 1
	var errs := BuildingLibrary.validate(req)
	if not errs.is_empty():
		res.fail("%s: refused %s" % [label, str(errs)])
		return
	var b := BrickWild.generate(req)
	if not b.is_ok():
		res.fail("%s: did not build %s" % [label, str(b.errors)])
		return
	var rep := BrickWild.check(b)
	var spec: HouseSpec = b.spec
	# the look reached the house: its wall is the colour asked for
	if req.look.has("wall") and spec.wall_color.to_html(false) != String(req.look["wall"][0]):
		res.fail("%s: wall #%s, the look asked for #%s" % [label, spec.wall_color.to_html(false), req.look["wall"][0]])
	if req.look.has("roof_types") and String(spec.roof_type) != String(req.look["roof_types"][0]):
		res.fail("%s: a %s roof, the look asked for %s" % [label, spec.roof_type, req.look["roof_types"][0]])
	for f in rep.get("failures", []):
		res.fail("%s: %s" % [label, str(f)])
	for w in rep.get("warnings", []):
		res.warn("%s: %s" % [label, str(w)])
	res.note("%-36s %-13s st%d %-8s %-7s fail %d warn %d" % [label, spec.style, spec.storeys,
		spec.roof_type, spec.roof_material, rep.get("failures", []).size(), rep.get("warnings", []).size()])
