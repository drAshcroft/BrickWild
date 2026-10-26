extends SceneTree
## WITCH-PROPS probe: stove, brooms and the basic household pieces of the six frozen huts.
func _init() -> void:
	for w_l in [[5.5, 7.0], [7.0, 9.0]]:
		for seed in [1, 8102, 21325]:
			var spec := HouseSpec.new()
			spec.style = &"witch_hut"
			spec.width = w_l[0]
			spec.length = w_l[1]
			spec.height = 2.6
			var plan := HouseGenerator.generate(spec, seed, true)
			var cats := {}
			for f in plan.furniture:
				cats[f.get("cat", "")] = int(cats.get(f.get("cat", ""), 0)) + 1
			var br: Dictionary = HouseGeometry.hearth_breast(plan)
			var check: Dictionary = HouseFurnishCheck.new().check(plan)
			var nav: Dictionary = HouseNavCheck.new().check(plan)
			print("== ", w_l, " seed ", seed, " rooms=", plan.rooms.size(), " stove=", not br.get("stove", {}).is_empty(),
				" brooms=", plan.witch_props.size(), " bed=", cats.get("bed", 0), " table=", cats.get("table", 0),
				" seat=", cats.get("seat", 0), " bench=", cats.get("workbench", 0), " furnish_ok=", check.get("ok"), " nav_ok=", nav.get("ok"))
			if not check.get("ok", true):
				print("   FAIL ", JSON.stringify(check.get("failures", [])).substr(0, 500))
	quit(0)
