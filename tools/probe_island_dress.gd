extends SceneTree
## Probe: which dressing step the island spends its time in.
func _init() -> void:
	var ground: VillageTerrain = load("res://tests/fixtures/terrain/synthetic_terrain.gd").make("islet")
	var s := VillageSpec.new(4242)
	s.population = 89
	s.terrain = ground
	s.purpose = &"fishing"
	s.water = &"coast"
	s.generate(4242)
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(s))
	var plan := VillageSitePlanner.plan(s, 0, 1.0)
	VillageLotPlanner.cut_measured(plan, jobs)
	VillageEnclosurePlan.author(plan)
	VillageAccessSteps.plan(plan)
	var t := Time.get_ticks_msec()
	var lap := func(label: String) -> void:
		var n := Time.get_ticks_msec()
		print("%-28s %.1f s" % [label, (n - t) / 1000.0])
		t = n
	plan.props.clear()
	plan.plants.clear()
	VillageDressContext.outer_land(plan)
	lap.call("outer_land")
	VillageGarden.dig_ponds(plan)
	lap.call("dig_ponds")
	var ctx: Dictionary = VillageDressContext.make_context(plan)
	lap.call("make_context")
	VillageDressContext.enclosure_hedge(plan, ctx)
	VillageDressContext.mill_wheels(plan, ctx)
	VillageDressContext.mine_adit(plan, ctx)
	lap.call("hedge/mill/adit")
	VillageDressContext.wood(plan, ctx)
	lap.call("wood")
	for step in [&"common", &"market", &"church", &"gate", &"water"]:
		VillageDressHosts.dress_place(plan, ctx, step)
		lap.call("place " + String(step))
	for i in range(plan.buildings.size()):
		VillageDressHosts.dress_building(plan, ctx, i)
	lap.call("buildings")
	VillageDressContext.blight_remnants(plan, ctx)
	VillageDressPlacement.hedges(plan, ctx)
	lap.call("hedges")
	VillageDressHosts.dress_place(plan, ctx, &"edge")
	lap.call("edge")
	VillageDressHosts.dress_place(plan, ctx, &"strand")
	lap.call("strand")
	VillageDressHosts.dress_place(plan, ctx, &"reeds")
	lap.call("reeds")
	VillageDresser._lush_pass(plan, ctx)
	lap.call("lush")
	VillageGarden.plant(plan, ctx)
	lap.call("garden plant")
	VillageDresser.open_ground(plan, ctx)
	lap.call("open_ground")
	quit(0)
