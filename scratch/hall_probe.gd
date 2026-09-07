extends SceneTree
## Scratch: how do great halls actually come out? Measure, then tune.
##
##   godot --headless --path . --script res://scratch/hall_probe.gd -- 200


func _init() -> void:
	var n := 200
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			n = a.to_int()
	var made := 0
	var skipped := 0
	var rows := 0
	var two_rows := 0
	var lord := 0
	var no_hearth := 0
	var plan_fail := {}
	var furnish_fail := {}
	var nav_fail := {}
	var comp := {}
	var bad: Array[String] = []
	var widths: Array[float] = []
	var styles: Array = CastleSpec.STYLES.keys()
	var r := RandomNumberGenerator.new()
	r.seed = 20260906
	for i in range(n):
		var spec := CastleSpec.new()
		spec.style = styles[i % styles.size()]
		spec.width = r.randf_range(8.0, 200.0)
		spec.length = spec.width * r.randf_range(1.0, 2.2)
		spec.height = r.randf_range(5.0, 26.0)
		CastleGenerator.generate(spec, 7000 + i)
		var plan: HousePlan = CastleGenerator.hall_plan(spec)
		if plan.spec == null:
			skipped += 1
			continue
		made += 1
		var f: Rect2 = HouseGeometry.room_floor_rect(plan, 0)
		widths.append(minf(f.size.x, f.size.y))
		var groups := {}
		var behind := 0
		var hearths := 0
		for p in plan.furniture:
			if String(p.get("row", "")) != "":
				groups[String(p["row"])] = true
			var cat: String = PropCatalog.category(String(p["key"]))
			if cat == "hearth":
				hearths += 1
			if cat == "bench" and plan.dais_rect().has_point(
					Vector2(p["pos"].x, p["pos"].z)):
				behind += 1
		rows += groups.size()
		if groups.size() >= 2:
			two_rows += 1
		if behind > 0:
			lord += 1
		if hearths == 0:
			no_hearth += 1
		for room in plan.compromises:
			for c in plan.compromises[room]:
				_bump(comp, String(c))
		var pc: Dictionary = HousePlanCheck.new().check(plan)
		for m in pc["failures"]:
			_bump(plan_fail, String(m).split(":")[0])
		var fc: Dictionary = HouseFurnishCheck.new().check(plan)
		for m2 in fc["failures"]:
			_bump(furnish_fail, String(m2).split(":")[0])
		var nc: Dictionary = HouseNavCheck.new().check(plan)
		for m3 in nc["failures"]:
			_bump(nav_fail, String(m3).split(":")[0])
		if bad.size() < 3 and (not pc["ok"] or not fc["ok"] or not nc["ok"]):
			bad.append("seed %d  %s  %.1f x %.1f m\n  plan: %s\n  furnish: %s\n  nav: %s"
				% [7000 + i, String(spec.style), f.size.x, f.size.y,
					pc["failures"], fc["failures"], nc["failures"]])
	widths.sort()
	print("halls %d of %d (skipped %d)" % [made, n, skipped])
	if made > 0:
		print("  narrow side: min %.1f  median %.1f  max %.1f"
			% [widths[0], widths[widths.size() / 2], widths[-1]])
		print("  trestle rows: %.2f per hall; two or more in %d of %d (%.0f%%)"
			% [float(rows) / float(made), two_rows, made,
				100.0 * float(two_rows) / float(made)])
		print("  a bench on the dais in %d of %d" % [lord, made])
		print("  no hearth in %d of %d" % [no_hearth, made])
	print("  compromises:      ", comp)
	print("  plan failures:    ", plan_fail)
	print("  furnish failures: ", furnish_fail)
	print("  nav failures:     ", nav_fail)
	for b in bad:
		print("---\n", b)
	quit()


func _bump(d: Dictionary, k: String) -> void:
	d[k] = int(d.get(k, 0)) + 1
