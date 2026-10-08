extends SceneTree
func _init() -> void:
	var phase := "walk"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("phase="): phase = arg.substr(6)
	var result := SuiteResult.new("furnishing " + phase)
	var started := Time.get_ticks_msec()
	match phase:
		"hearth":
			HouseQASuite._hearth_fixture(result)
			HouseQASuite._hearth_sweep(result, 12)
			HouseQASuite._row_fixture(result)
			HouseQASuite._screens_fixture(result)
			HouseQASuite._rule_override_fixture(result)
		"affinity":
			HouseQASuite._affinity_sweep(result, 12, false)
			HouseQASuite._affinity_variety(result, 8)
			HouseQASuite._affinity_fixture(result)
		"composition":
			HouseQASuite._feng_shui_fixtures(result)
			HouseQASuite._seed_60068_shelf_over(result)
			HouseQASuite._feng_shui_sweep(result, 12, false)
		"walk":
			for method in ["_wq_furniture_floor", "_wq_bench_at_table_end", "_wq_door_approach", "_wq_outdoor_lamp", "_wq_second_dining_table", "_wq_surface_in_reach"]:
				print("START ", method)
				match method:
					"_wq_furniture_floor": HouseQASuite._wq_furniture_floor(result)
					"_wq_bench_at_table_end": HouseQASuite._wq_bench_at_table_end(result)
					"_wq_door_approach": HouseQASuite._wq_door_approach(result)
					"_wq_outdoor_lamp": HouseQASuite._wq_outdoor_lamp(result)
					"_wq_second_dining_table": HouseQASuite._wq_second_dining_table(result)
					"_wq_surface_in_reach": HouseQASuite._wq_surface_in_reach(result)
				print("END ", method)
		_:
			quit(2)
			return
	print(result.summary())
	print("elapsed_seconds=", float(Time.get_ticks_msec() - started) / 1000.0)
	for failure in result.failures: printerr(failure)
	for warning in result.warnings: print("WARNING ", warning)
	quit(0 if result.ok() else 1)
