extends SceneTree
## Probe: the form reading of the sites that derive valley (VTER-VALLEY-REAL).
const S := preload("res://tests/suites/village_valley_suite.gd")

func _init() -> void:
	for n in ["real30/ushguli", "world90/lake_argyle", "world90/balan", "world90/rocamadour", "world90/gangotri",
			"world90/vermont", "world90/lugar_de_guene", "world90/haldenstein", "world90/shirakawa_go", "world90/batad"]:
		var g := S.terrain(n)
		if g == null:
			print(n, " missing")
			continue
		var spec := S.spec_for(g)
		var r := VillageSpec.read_ground(g, spec.form_window_m())
		var s := ""
		for k in ["slope_median", "slope_p75", "centre_rank", "relief_m", "level_share", "level_regions", "level_largest"]:
			s += " %s=%s" % [k, snappedf(float(r.get(k, -1)), 0.01)]
		print("%-24s form=%s%s" % [n, spec.form_intent, s])
	quit()
