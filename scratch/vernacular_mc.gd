extends SceneTree
## Genome-level distribution of each region (no building): what share of
## houses carries each signature trait, as the sampler draws them.

func _init() -> void:
	var n := 4000
	for id in VillageVernacular.region_ids():
		var fs := VillageVernacular.resolve({String(id): 1.0})
		var shares := fs.tier_shares(0.5)
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var count := {}
		var types := {}
		for i in range(n):
			var x := rng.randf()
			var tier: StringName = &"poor" if x < float(shares[&"poor"]) else (&"rich" if x > 1.0 - float(shares[&"rich"]) else &"middle")
			var g := fs.house("mc|%d" % i, tier, &"farming", &"farmer" if i % 2 == 0 else &"none")
			types["%s/%s" % [tier, g["type"]]] = int(types.get("%s/%s" % [tier, g["type"]], 0)) + 1
			for k in ["style:" + String(g["style"]), "storeys:%d" % g["storeys"],
					"form:" + String(g["clusters"]["roof_form"]), "material:" + String(g["look"].get("roof_material", "?")),
					"wall:" + String(g["clusters"]["walls"]), "trim:" + String(g["clusters"]["trim"])]:
				count[k] = int(count.get(k, 0)) + 1
		var keys := count.keys()
		keys.sort()
		var line := ""
		for k in keys:
			line += "%s=%.2f  " % [k, float(count[k]) / n]
		print("== %s (tiers %s)\n%s" % [id, str(shares), line])
		var tk := types.keys()
		tk.sort()
		var tl := ""
		for k in tk:
			tl += "%s=%.3f  " % [k, float(types[k]) / n]
		print("   types: ", tl)
	quit()
