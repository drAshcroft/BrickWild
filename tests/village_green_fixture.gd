extends SceneTree
## Bounded render-review regression. Native buildings are generated afresh;
## every VillageQA rule runs, including well access and complete programmes.
## Run: godot --headless --path . --script res://tests/village_green_fixture.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	var warnings := 0
	for seed in [9203, 9208, 9210, 9211]:
		print("GREEN START seed=", seed)
		var spec := VillageCheckSuite._spec(seed, 40, &"farming", 0.3)
		var plan := VillageLotPlanner.plan(spec)
		var report := VillageQA.new().check(plan, {}, false)
		print("GREEN seed=", seed, " buildings=", plan.buildings.size(),
			" site=", plan.site.size, " stats=", report["stats"])
		for failure in report["failures"]:
			print("FAIL ", failure)
		for warning in report["warnings"]:
			print("WARN ", warning)
		failures += report["failures"].size()
		warnings += report["warnings"].size()
	print("GREEN 4 cases, ", failures, " failures, ", warnings, " warnings")
	quit(0 if failures == 0 else 1)
