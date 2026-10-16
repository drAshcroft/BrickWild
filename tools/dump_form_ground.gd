extends SceneTree
## The ground reading (VillageSpec.read_ground) of every world site with a
## world90 grid, beside its spec inputs and hand label, as JSON on stdout
## between BEGIN/END markers -- the evidence the terrain form rule was fitted
## on (VTER-FORM-DERIVE; docs/VILLAGE_TERRAIN.md).
##
##   godot --headless --path . --script res://tools/dump_form_ground.gd > artifacts/form_ground.log

const FIXTURE := "res://tests/fixtures/settlements/world_settlements.json"
const WORLD90 := "res://tests/fixtures/terrain/world90/"


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORLD90 + "index.json"))["sites"]
	var rows: Array = []
	for s in data["sites"]:
		if not bool(s["morph"].get("usable", false)) or not index.has(s["name"]):
			continue
		var path: String = WORLD90 + String(index[s["name"]])
		var ground := VillageTerrain.from_file(path)
		var r := VillageSpec.read_ground(ground, 400.0)
		var about: String = JSON.parse_string(FileAccess.get_file_as_string(path)).get("about", "")
		var m: Dictionary = s["spec"]
		var w: String = m["water"]
		if about.contains("; lake:"):
			w = "lake"
		for k in ["water_near_m", "water_far_m"]:
			if r.has(k) and is_inf(float(r[k])):
				r[k] = 1e9
		rows.append({"name": s["name"], "label": m.get("label_form", ""), "conf": m.get("label_confidence", ""),
			"population": m["population"], "purpose": m["purpose"], "water": w,
			"culture": m["culture"], "nearest": m["nearest_form"], "read": r})
	print("BEGIN")
	print(JSON.stringify(rows))
	print("END")
	quit(0)
