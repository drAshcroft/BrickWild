extends SceneTree
## Probe the realism sample plan by plan (VTER-REAL-*), without the whole gate.
## Plans the named sample sites (default: all of vrealism's SAMPLE), writes each
## plan's VillageShape to artifacts/vter_real/plans/<name>.json, then judges every
## cached plan exactly as the suite does and lists the cells out of band and the
## cells that left the baseline. `-- judge` only re-judges the cache.
## Env: NONET=1 without the back streets, NOTURN=1 without the frontage turn,
## ROADS=1 prints the road list.
##   godot --headless --path . --script res://tools/probe_realism.gd -- Lelu Tofta
const SUITE := preload("res://tests/suites/village_realism_suite.gd")
const CACHE := "res://artifacts/vter_real/plans/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE))
	var names: Array = []
	var judge_only := false
	for a in OS.get_cmdline_user_args():
		if a == "judge":
			judge_only = true
		else:
			names.append(a)
	if names.is_empty() and not judge_only:
		names = SUITE.SAMPLE
	VillageLotPlanner._StreetNet.enabled = OS.get_environment("NONET") != "1"
	VillageLotPlanner.turn_enabled = OS.get_environment("NOTURN") != "1"
	var sites: Array = SUITE._real_sites()
	var ground: Dictionary = SUITE._ground_index()
	for name in names:
		var site: Dictionary = SUITE._site(sites, name)
		var t0 := Time.get_ticks_msec()
		var plan: VillagePlan = SUITE._plan(site, ground[name])
		if plan == null:
			print(name, ": no plan")
			continue
		var m := VillageShape.measure(plan)
		var lot := VillageLotCheck.new().check(plan)
		var road := VillageRoadCheck.new().check(plan)
		print("%s form=%s houses=%d %.1fs lotcheck=%s roadcheck=%s" % [name, plan.spec.form,
			plan.buildings.size(), (Time.get_ticks_msec() - t0) / 1000.0,
			(lot["failures"] as Array).slice(0, 4), (road["failures"] as Array).slice(0, 4)])
		if OS.get_environment("ROADS") == "1":
			for i in range(plan.roads.size()):
				var r: Dictionary = plan.roads[i]
				var p: PackedVector2Array = r["points"]
				var touch := []
				for j in range(plan.roads.size()):
					if j != i and VillageSitePlanner._roads_touch(p, plan.roads[j]["points"]):
						touch.append(j)
				print("   road %d %s loop=%s n=%d %s -> %s touches %s" % [i, r["class"], r.get("loop", false), p.size(), p[0], p[p.size() - 1], touch])
		var keep := {}
		for k in SUITE.METRICS:
			keep[k] = m.get(k)
		print("   ", keep)
		var f := FileAccess.open(CACHE + name + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(keep))
		f.close()
	_judge(sites)
	quit()


func _judge(sites: Array) -> void:
	var cells := {}
	for st in SUITE.STRATA:
		cells[st] = {}
		for m in SUITE.METRICS:
			cells[st][m] = {"real": [], "gen": []}
	for s in sites:
		for st in SUITE.STRATA:
			if SUITE.in_stratum(st, s):
				for m in SUITE.METRICS:
					var v = s["morph"].get(m)
					if v != null:
						cells[st][m]["real"].append(float(v))
	var have := 0
	for name in SUITE.SAMPLE:
		var path: String = CACHE + name + ".json"
		if not FileAccess.file_exists(path):
			continue
		have += 1
		var shape: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var site: Dictionary = SUITE._site(sites, name)
		for st in SUITE.STRATA:
			if SUITE.in_stratum(st, site):
				for m in SUITE.METRICS:
					if shape.get(m) != null:
						cells[st][m]["gen"].append(float(shape[m]))
	var table: Dictionary = SUITE.judge(cells)
	var now: Dictionary = SUITE.states(table)
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SUITE.BASELINE))["cells"]
	var n_in := 0
	for k in now:
		if now[k]:
			n_in += 1
	print("JUDGE %d of %d plans cached: %d of %d cells in (%.1f %%)" % [have, SUITE.SAMPLE.size(),
		n_in, now.size(), 100.0 * n_in / maxi(1, now.size())])
	for st in table:
		for m in table[st]:
			var row: Dictionary = table[st][m]
			var k: String = SUITE.cell_key(st, m)
			var was: String = "" if not base.has(k) else ("was in" if base[k] else "was out")
			if row["state"] in ["low", "high"]:
				print("  OUT %-28s %8s (%s-%s) %s %s" % [k, str(row["gen"]), str(row["p10"]), str(row["p90"]), row["state"], was])
			elif row["state"] == "in" and base.has(k) and not base[k]:
				print("  NEW IN %s %s" % [k, str(row["gen"])])
	for k in SUITE.regressions(base, now):
		print("  REGRESSION ", k)
