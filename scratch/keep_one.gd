extends SceneTree
## The one keep that kills the runner, a stage at a time, flushed to disk.

const OUT := "res://scratch/logs/keep_one.txt"


func _init() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	var spec: CastleSpec = CastleSweep.spec_at(&"bavarian", &"fortress", 1)
	var box: AABB = CastleGeometry.keep_aabb(spec)
	f.store_line("keep mass %.2f x %.2f x %.2f" % [box.size.x, box.size.z, box.size.y])
	f.flush()

	# rebuild what keep_plan does, stage by stage, without furnishing
	var levels: int = clampi(int(box.size.y / CastleInteriorPlans.KEEP_STOREY_H), 3,
		HouseGeometry.MAX_STOREYS)
	f.store_line("levels %d" % levels)
	f.flush()
	var plan: HousePlan = CastleKeepPlan.generate(spec)
	if plan.spec == null:
		f.store_line("no plan (bounded out)")
		f.close()
		print("done")
		quit()
		return
	f.store_line("plan built: %d rooms, %d windows, %d stairs, %d furniture"
		% [plan.room_count(), plan.windows.size(), plan.stairs.size(),
			plan.furniture.size()])
	f.store_line("interior %s" % str(HouseGeometry.interior_rect(plan.spec)))
	f.flush()
	HousePlanCheck.new().check(plan)
	f.store_line("plan check ok")
	f.flush()
	HouseFurnishCheck.new().check(plan)
	f.store_line("furnish check ok")
	f.flush()
	HouseNavCheck.new().check(plan)
	f.store_line("nav check ok")
	f.close()
	print("done")
	quit()
