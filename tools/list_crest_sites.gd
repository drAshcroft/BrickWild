extends SceneTree
## Which measured world sites derive the `crest` form on their cached 90 m
## ground, with the spec the world set gives them (VTER-FORM-CREST).
##
##   godot --headless --path . --script res://tools/list_crest_sites.gd > artifacts/vter_form_crest/sites.log 2>&1

const FIXTURE := "res://tests/fixtures/settlements/world_settlements.json"
const WORLD90 := "res://tests/fixtures/terrain/world90/"


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORLD90 + "index.json"))["sites"]
	var i := -1
	var n := 0
	for s in data["sites"]:
		if not bool(s["morph"].get("usable", false)):
			continue
		i += 1
		if not index.has(s["name"]):
			continue
		var spec := spec_for(s, i, index)
		if not spec.valid():
			continue
		spec.generate(spec.seed)
		if spec.form_intent != &"crest":
			continue
		n += 1
		print("%-28s pop %3d culture %-10s purpose %-9s enclosure %-8s water %-6s file %s" % [
			s["name"], spec.population, spec.culture, spec.purpose, spec.enclosure, spec.water,
			index[s["name"]]])
	print("crest sites: %d" % n)
	quit(0)


static func spec_for(s: Dictionary, i: int, index: Dictionary) -> VillageSpec:
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
