extends SceneTree
## THROWAWAY. The feng shui sweep fixture that fails: which styles fail it at
## the same size and seed, and what does the plan look like?

func _init() -> void:
	for style in HouseSpec.STYLES.keys():
		var spec := HouseSpec.new()
		spec.style = style
		spec.trade = &"smith"
		spec.width = 6.0
		spec.length = 17.8
		spec.storeys = 1
		var plan: HousePlan = HouseGenerator.generate(spec, 60020)
		var rep: Dictionary = HouseFurnishCheck.new().check(plan)
		var f: Array[String] = []
		for x in rep["failures"]:
			f.append(String(x))
		var bench := ""
		for p in plan.furniture:
			if String(p.get("cat", "")) == "workbench":
				bench = str(p.get("rect", ""))
		print("%-15s wall=%.2f interior=%.2f fails=%s bench=%s"
			% [String(style), HouseGeometry.wall_thickness(spec),
				HouseGeometry.interior_rect(spec).size.x, str(f), bench])
	quit()
