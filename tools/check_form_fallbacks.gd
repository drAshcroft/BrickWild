extends SceneTree
## Does every terrain form's FALLBACK plan on real ground? For each
## form_intent the world sites derive (VillageSpec.FORM_FALLBACK), plan the
## smallest such site on its world90 grid and report the planned form, roads,
## lots and buildings against the programme (VTER-FORM-DERIVE).
##
##   godot --headless --path . --script res://tools/check_form_fallbacks.gd > artifacts/fallbacks.log 2>&1

const FIXTURE := "res://tests/fixtures/settlements/world_settlements.json"
const WORLD90 := "res://tests/fixtures/terrain/world90/"


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORLD90 + "index.json"))["sites"]
	var pick := {}
	var i := -1
	for s in data["sites"]:
		if not bool(s["morph"].get("usable", false)):
			continue
		i += 1
		if not index.has(s["name"]):
			continue
		var spec := _spec(s, i, index)
		if not spec.valid():
			continue
		spec.generate(spec.seed)
		var prior: Dictionary = pick.get(spec.form_intent, {})
		if prior.is_empty() or spec.population < int(prior["spec"].population):
			pick[spec.form_intent] = {"site": s, "spec": spec}
	var bad := 0
	var keys := pick.keys()
	keys.sort()
	for intent in keys:
		var spec: VillageSpec = pick[intent]["spec"]
		var t0 := Time.get_ticks_msec()
		var plan: VillagePlan = VillageLotPlanner.plan(spec)
		var wanted := VillageProgrammer.programme(spec).size()
		var ok := not plan.roads.is_empty() and plan.buildings.size() >= wanted
		bad += int(not ok)
		print("%s %-9s planned as %-8s %-24s pop %3d water %-6s: %d roads, %d lots, %d/%d buildings, %.1f s" % [
			"OK  " if ok else "FAIL", intent, spec.form, pick[intent]["site"]["name"], spec.population,
			spec.water, plan.roads.size(), plan.lots.size(), plan.buildings.size(), wanted,
			(Time.get_ticks_msec() - t0) / 1000.0])
	print("fallbacks: %d intents, %d failed" % [keys.size(), bad])
	quit(1 if bad > 0 else 0)


func _spec(s: Dictionary, i: int, index: Dictionary) -> VillageSpec:
	var path: String = WORLD90 + String(index[s["name"]])
	var m: Dictionary = s["spec"]
	var spec := VillageSpec.new(9000 + i)
	spec.population = int(m["population"])
	spec.culture = StringName(m["culture"])
	spec.purpose = StringName(m["purpose"])
	spec.enclosure = StringName(m["enclosure"])
	var about: String = JSON.parse_string(FileAccess.get_file_as_string(path)).get("about", "")
	spec.water = &"lake" if about.contains("; lake:") else StringName(m["water"])
	spec.terrain = VillageTerrain.from_file(path)
	return spec
