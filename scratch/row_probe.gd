extends SceneTree
func _init() -> void:
	var spec: CastleSpec = CastleSweep.spec_at(&"edwardian", &"castle", 1)
	var plan: HousePlan = CastleInteriorPlans.chapel_plan(spec)
	print("furniture ", plan.furniture.size(), " compromises ", plan.compromises)
	quit()
