extends SceneTree
## VTER-REAL-SAMPLE: how often do two runs of the UNCHANGED planner on disjoint
## seed sets agree on a cell's verdict? Reads the plans cached by
## tools/probe_realism_seeds.gd (artifacts/vter_sample/plans/<seed>/).
##   godot --headless --path . --script res://tools/realism_agreement.gd -- 4242,101,202 303,404,505
## With no arguments: every single-seed pair (the old gate), and every 3 + 3 split
## of the six cached seeds (the new gate).
const SUITE := preload("res://tests/suites/village_realism_suite.gd")
const CACHE := "res://artifacts/vter_sample/plans/"
const ALL: Array[int] = [4242, 101, 202, 303, 404, 505]


func _init() -> void:
	var sites: Array = SUITE._real_sites()
	var args := OS.get_cmdline_user_args()
	if args.size() == 2:
		_pair(sites, _seeds(args[0]), _seeds(args[1]), true)
	else:
		var old_in := 0.0
		var old_n := 0
		for i in range(ALL.size()):
			for j in range(i + 1, ALL.size()):
				old_in += _pair(sites, [ALL[i]], [ALL[j]], false)["point"]
				old_n += 1
		print("OLD GATE (1 seed vs 1 seed, point median) mean over %d pairs: %.1f %%" % [old_n, old_in / old_n])
		var sum := {"point": 0.0, "bin": 0.0, "out": 0.0, "three": 0.0, "dec": 0.0, "unsure": 0.0}
		var n := 0
		for mask in range(64):
			if _bits(mask) != 3 or (mask & 1) == 0:
				continue
			var a: Array[int] = []
			var b: Array[int] = []
			for k in range(6):
				if mask & (1 << k):
					a.append(ALL[k])
				else:
					b.append(ALL[k])
			var r := _pair(sites, a, b, false)
			for k in sum:
				sum[k] += r[k]
			n += 1
		print("NEW GATE (3 seeds vs 3 seeds) mean over %d splits: point %.1f %%, in/not-in %.1f %%, OUT/not-out %.1f %%, three-state %.1f %%, decisive-only %.1f %%, unsure share %.1f %%" % [
			n, sum["point"] / n, sum["bin"] / n, sum["out"] / n, sum["three"] / n, sum["dec"] / n, sum["unsure"] / n])
		_pair(sites, [4242, 101, 202], [303, 404, 505], true)
	quit()


func _bits(m: int) -> int:
	var c := 0
	while m:
		c += m & 1
		m >>= 1
	return c


func _seeds(t: String) -> Array[int]:
	var out: Array[int] = []
	for p in t.split(","):
		out.append(int(p))
	return out


func _table(sites: Array, seeds: Array) -> Dictionary:
	var rows: Array = []
	for sd in seeds:
		for name in SUITE.SAMPLE:
			var path: String = CACHE + str(sd) + "/" + name + ".json"
			if FileAccess.file_exists(path):
				rows.append({"name": name, "seed": sd, "shape": JSON.parse_string(FileAccess.get_file_as_string(path))})
	return SUITE.judge(SUITE.build_cells(sites, rows))


func _pair(sites: Array, a: Array, b: Array, verbose: bool) -> Dictionary:
	var ta := _table(sites, a)
	var tb := _table(sites, b)
	var n := 0
	var point := 0
	var bin := 0
	var outc := 0
	var three := 0
	var dec_both := 0
	var dec_agree := 0
	var unsure := 0
	for st in ta:
		for m in ta[st]:
			var ra: Dictionary = ta[st][m]
			var rb: Dictionary = tb[st][m]
			if ra["state"] == "na" or rb["state"] == "na":
				continue
			n += 1
			if (ra["point"] == "in") == (rb["point"] == "in"):
				point += 1
			if (ra["state"] == "in") == (rb["state"] == "in"):
				bin += 1
			if (ra["state"] in ["low", "high"]) == (rb["state"] in ["low", "high"]):
				outc += 1
			if ra["state"] == rb["state"]:
				three += 1
			if ra["state"] == "unsure":
				unsure += 1
			if ra["state"] != "unsure" and rb["state"] != "unsure":
				dec_both += 1
				if (ra["state"] == "in") == (rb["state"] == "in"):
					dec_agree += 1
			if verbose and ra["state"] != rb["state"]:
				print("  differs %s/%s: A %s [%s-%s] B %s [%s-%s] band %s-%s" % [st, m, ra["state"],
					SUITE._fmt(ra["lo"]), SUITE._fmt(ra["hi"]), rb["state"], SUITE._fmt(rb["lo"]),
					SUITE._fmt(rb["hi"]), SUITE._fmt(ra["p10"]), SUITE._fmt(ra["p90"])])
	var r := {"point": 100.0 * point / maxi(1, n), "bin": 100.0 * bin / maxi(1, n), "out": 100.0 * outc / maxi(1, n),
		"three": 100.0 * three / maxi(1, n), "dec": 100.0 * dec_agree / maxi(1, dec_both),
		"unsure": 100.0 * unsure / maxi(1, n)}
	if verbose:
		print("A=%s B=%s cells=%d: point %.1f %%, in/not-in %.1f %%, OUT/not-out %.1f %%, three-state %.1f %%, decisive-only %.1f %% (%d of %d both decisive), unsure share %.1f %%" % [
			a, b, n, r["point"], r["bin"], r["out"], r["three"], r["dec"], dec_both, n, r["unsure"]])
	return r
