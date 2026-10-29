extends RefCounted
## VTER-VISUAL-CHARACTER (`vcharacter`): the three real-ground villages carry
## their few traits (qa/village_character_check.gd), planted the way the render
## and the walk do it (population 40, seed 1, form chosen by the planner), and
## the same ground WITHOUT its character -- the default Norman spec -- fails.

const REAL30 := "res://tests/fixtures/terrain/real30/"


static func run() -> SuiteResult:
	var res := SuiteResult.new("vcharacter")
	var t0 := Time.get_ticks_msec()
	var sites: Array = (OS.get_environment("CHARACTER_SITE").split(",") if OS.get_environment("CHARACTER_SITE") != ""
		else VillageCharacterCheck.TRAITS.keys())
	for site in sites:
		var ground := VillageCharacterCheck.apply(VillageTerrain.from_file(REAL30 + "%s.json" % site), site)
		res.checked += 1
		if not ground.valid():
			res.fail("%s: the fixture does not read" % site)
			continue
		var want: Dictionary = VillageCharacterCheck.TRAITS[site]
		res.checked += 1
		if ground.character.is_empty():
			res.fail("%s: the fixture carries no character" % site)
			continue
		var m := _measure(ground, float(want["gap_max"]))
		var bad := VillageCharacterCheck.problems(m, want)
		res.checked += 1
		for p in bad:
			res.fail("%s: %s" % [site, p])
		res.note("%-10s dwellings %d styles %s storeys %.1f near %d (median gap %.1f m) | %s" % [
			site, m["dwellings"], m["styles"], m["storeys"], m["near"], m["gap"], "ok" if bad.is_empty() else "FAILS"])
		# control: the same ground with no character is the default Norman spec
		# (programme only: the style and storeys are the request's, and the gap
		# is a layout that costs minutes to plan again)
		var plain := VillageTerrain.from_file(REAL30 + "%s.json" % site)
		plain.character = {}
		var pm := _programme_measure(plain)
		var pbad := VillageCharacterCheck.problems(pm, want)
		res.checked += 1
		if pbad.is_empty():
			res.fail("control %s: the default spec passed the trait check" % site)
		res.note("control %-10s (must fail): styles %s storeys %.1f -> %s" % [
			site, pm["styles"], pm["storeys"], "; ".join(pbad)])
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func _measure(ground: VillageTerrain, gap_max: float) -> Dictionary:
	var spec := VillageSpec.new(1)
	spec.population = 40
	spec.terrain = ground
	spec.generate(1)
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(spec))
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	if plan.ground == null or plan.buildings.is_empty():
		return {"dwellings": 0, "styles": {}, "storeys": 0.0, "gap": 999.0, "near": 0}
	return VillageCharacterCheck.measure(plan, gap_max)


## Style and storeys from the programme alone (no layout): the gap is left out.
static func _programme_measure(ground: VillageTerrain) -> Dictionary:
	var spec := VillageSpec.new(1)
	spec.population = 40
	spec.terrain = ground
	spec.generate(1)
	var styles := {}
	var storeys: Array[float] = []
	var n := 0
	for req in VillageProgrammer.programme(spec):
		if req.kind in [&"house", &"shop"]:
			n += 1
			styles[req.style] = int(styles.get(req.style, 0)) + 1
			if req.kind == &"house":
				storeys.append(float(req.storeys))
	return {"dwellings": n, "styles": styles, "storeys": VillageCharacterCheck._median(storeys), "gap": 0.0, "near": n}
