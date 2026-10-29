extends SceneTree
## VTER-REAL-SAMPLE: plan every realism sample site under one or more seeds and
## cache each VillageShape to artifacts/vter_sample/plans/<seed>/<name>.json
## (a cached plan is skipped, so a run resumes).
##   godot --headless --path . --script res://tools/probe_realism_seeds.gd -- 101 202
const SUITE := preload("res://tests/suites/village_realism_suite.gd")
const CACHE := "res://artifacts/vter_sample/plans/"


func _init() -> void:
	var sites: Array = SUITE._real_sites()
	var ground: Dictionary = SUITE._ground_index()
	for a in OS.get_cmdline_user_args():
		var sd := int(a)
		var dir := CACHE + str(sd) + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		for name in SUITE.SAMPLE:
			if FileAccess.file_exists(dir + name + ".json"):
				continue
			var t0 := Time.get_ticks_msec()
			var plan: VillagePlan = SUITE._plan(SUITE._site(sites, name), ground[name], sd)
			if plan == null or plan.buildings.is_empty():
				print(sd, " ", name, ": no plan")
				continue
			var m := VillageShape.measure(plan)
			var keep := {}
			for k in SUITE.METRICS:
				keep[k] = m.get(k)
			var f := FileAccess.open(dir + name + ".json", FileAccess.WRITE)
			f.store_string(JSON.stringify(keep))
			f.close()
			print("%d %s %.1fs" % [sd, name, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
