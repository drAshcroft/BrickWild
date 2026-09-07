extends SceneTree
## Walk every castle in the sweep, writing progress to a file BEFORE each one
## and flushing. A crash loses stdout; it does not lose a flushed file, so the
## last line names the castle that did it.

const OUT := "res://scratch/logs/keep_crawl.txt"


func _init() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	for e in CastleSweep.each():
		var who := "%s %s %d" % [String(e["style"]), String(e["tier"]),
			int(e["index"])]
		f.store_line("start " + who)
		f.flush()
		var spec: CastleSpec = CastleSweep.spec_at(e["style"], e["tier"], int(e["index"]))
		var plan: HousePlan = CastleGenerator.keep_plan(spec)
		var note := "  no keep"
		if plan.spec != null:
			var box: AABB = CastleGeometry.keep_aabb(spec)
			note = "  keep %.1f x %.1f x %.1f -> %d storeys, %d windows" % [
				box.size.x, box.size.z, box.size.y, plan.spec.storeys,
				plan.windows.size()]
			HousePlanCheck.new().check(plan)
			HouseFurnishCheck.new().check(plan)
			HouseNavCheck.new().check(plan)
		f.store_line("  done " + who + note)
		f.flush()
	f.store_line("ALL DONE")
	f.close()
	print("crawl finished")
	quit()
