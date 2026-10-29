extends SceneTree
func _init() -> void:
	var site := OS.get_environment("CHARACTER_SITE")
	var ground := VillageTerrain.from_file("res://tests/fixtures/terrain/real30/%s.json" % site)
	var spec := VillageSpec.new(1)
	spec.population = 40
	spec.terrain = ground
	spec.generate(1)
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(spec))
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	print("FORM ", spec.form, " intent ", spec.form_intent, " bld ", plan.buildings.size(), " roads ", plan.roads.size())
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		var a := VillageMeasure.bounds_poly(b)
		var near := INF
		var nj := -1
		for j in plan.buildings.size():
			if j != i:
				var d := VillageMeasure.poly_distance(a, VillageMeasure.bounds_poly(plan.buildings[j]))
				if d < near:
					near = d
					nj = j
		var r: BuildingRequest = b["request"]
		print("B", i, " ", r.kind, " ", r.style, " st=", r.storeys, " cls=", b["class"], " w=", snappedf(r.width,0.1), " l=", snappedf(r.length,0.1), " near=", snappedf(near, 0.1), " (", nj, ") road=", plan.lots[int(b["lot"])].get("road", "?"))
	for r in plan.roads:
		print("ROAD ", r["class"], " pts ", (r["points"] as PackedVector2Array).size())
	quit()
