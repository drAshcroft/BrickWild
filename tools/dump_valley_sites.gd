extends SceneTree
## Which world90 sites (and real30 fixtures, and synthetic landforms) derive the
## `valley` form with the water their spec carries (VTER-FORM-VALLEY).
##   godot --headless --path . --script res://tools/dump_valley_sites.gd

const FIXTURE := "res://tests/fixtures/settlements/world_settlements.json"
const WORLD90 := "res://tests/fixtures/terrain/world90/"


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORLD90 + "index.json"))["sites"]
	for s in data["sites"]:
		if not bool(s["morph"].get("usable", false)) or not index.has(s["name"]):
			continue
		var path: String = WORLD90 + String(index[s["name"]])
		var ground := VillageTerrain.from_file(path)
		var m: Dictionary = s["spec"]
		var spec := VillageSpec.new(4242)
		spec.population = mini(int(m["population"]), 80)
		spec.purpose = StringName(m["purpose"])
		spec.water = StringName(m["water"]) if m["water"] in ["river", "stream", "pond", "coast", "lake", "none"] else &"none"
		spec.terrain = ground
		spec.generate(4242)
		if spec.form_intent == &"valley" or m.get("label_form", "") == "valley":
			print("%-22s intent=%s label=%s/%s water=%s relief=%.0f shape: elong %.2f dead %.2f" % [
				s["name"], spec.form_intent, m.get("label_form", ""), m.get("label_confidence", ""),
				m["water"], s["morph"].get("relief_disc_m", 0), s["morph"].get("elongation", 0), s["morph"].get("dead_end_ratio", 0)])
	for n in ["real30/hallstatt", "real30/ushguli", "real30/castelmezzano", "real30/eze", "real30/masouleh", "real30/rocamadour", "real30/positano"]:
		var g := VillageTerrain.from_file("res://tests/fixtures/terrain/%s.json" % n)
		for w in [&"river"]:
			var sp := VillageSpec.new(4242)
			sp.population = 50
			sp.purpose = &"farming"
			sp.water = w
			sp.terrain = g
			sp.generate(4242)
			print("%s with water=%s -> %s" % [n, w, sp.form_intent])
	quit(0)
