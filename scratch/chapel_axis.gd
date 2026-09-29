extends SceneTree
func _init() -> void:
	var spec: CastleSpec = CastleSweep.spec_at(&"edwardian", &"castle", 1)
	var plan: HousePlan = CastleInteriorPlans.chapel_plan(spec)
	print("axis: ", TempleRiteCheck.plan_axis_faults(plan, 0, plan.entrance()))
	var b := HouseBuilder.new()
	b.build(plan)
	var rep: Dictionary = HouseQA.new().check(plan, b)
	print("HouseQA ok=%s failures=%s" % [rep["ok"], str(rep["failures"]).substr(0, 300)])
	quit()
