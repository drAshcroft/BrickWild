extends SceneTree
## VTER-REAL-VERTICAL: judge cached realism plans (tools/probe_realism_seeds.gd) with
## the three-state verdict, print the cells named, write every cell's state and diff
## against an earlier state file.
##   godot --headless --path . --script res://tools/judge_cache.gd -- cache=res://artifacts/x/ out=res://artifacts/x/states.json base=res://artifacts/y/states.json metric=elev_span_m
const SUITE := preload("res://tests/suites/village_realism_suite.gd")


func _init() -> void:
	var root := "res://artifacts/vter_sample/plans/"
	var out := ""
	var base := ""
	var metric := "elev_span_m"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cache="):
			root = a.substr(6)
		elif a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("base="):
			base = a.substr(5)
		elif a.begins_with("metric="):
			metric = a.substr(7)
	var sites: Array = SUITE._real_sites()
	var rows: Array = []
	for sd in SUITE.SEEDS:
		for name in SUITE.SAMPLE:
			var path: String = root + str(sd) + "/" + name + ".json"
			if FileAccess.file_exists(path):
				rows.append({"name": name, "seed": sd, "shape": JSON.parse_string(FileAccess.get_file_as_string(path))})
	var table: Dictionary = SUITE.judge(SUITE.build_cells(sites, rows))
	var states := {}
	var n_in := 0
	var n_un := 0
	var n_out := 0
	for st in table:
		for m in table[st]:
			var r: Dictionary = table[st][m]
			if r["state"] == "na":
				continue
			states[st + "/" + m] = r["state"]
			match r["state"]:
				"in": n_in += 1
				"unsure": n_un += 1
				_: n_out += 1
			if m == metric:
				print("%-9s %s n_gen=%d gen %s [%s-%s] band %s-%s" % [st, String(r["state"]).to_upper(), r["n_gen"],
					SUITE._fmt(r["gen"]), SUITE._fmt(r["lo"]), SUITE._fmt(r["hi"]), SUITE._fmt(r["p10"]), SUITE._fmt(r["p90"])])
	print("TOTAL in %d unsure %d out %d (plans %d)" % [n_in, n_un, n_out, rows.size()])
	if base != "" and FileAccess.file_exists(base):
		var b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base))
		for k in states:
			var was: String = b.get(k, "na")
			if was != states[k]:
				var tag := ""
				if was == "in" and states[k] in ["low", "high"]:
					tag = "  <== REGRESSION"
				elif was in ["low", "high"] and states[k] == "in":
					tag = "  (gain)"
				print("  %s: %s -> %s%s" % [k, was, states[k], tag])
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(states))
		f.close()
	quit()
