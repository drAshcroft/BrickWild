extends SceneTree
func _init() -> void:
	HouseFurnisher._ROW_DEBUG = true
	var spec: CastleSpec = CastleSweep.spec_at(&"edwardian", &"castle", 1)
	var plan: HousePlan = CastleGenerator.chapel_plan(spec)
	print("furniture ", plan.furniture.size(), " compromises ", plan.compromises)
	quit()
