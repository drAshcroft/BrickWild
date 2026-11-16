extends SceneTree
## VILLAGE-PLACE: build a whole village of a place through the public path
## and judge it. For each place named (default: three far-apart presets) it
## generates the village, runs VillageVernacularCheck on the plan, and prints
## the settings that reached the spec, the buildings and the time.
##
##   godot --headless --path . --script res://tools/probe_place_village.gd -- british_hamlet congo_forest
##   ... -- pop=60 seed=7 check       also BrickWild.check (the village QA; slow)


func _init() -> void:
	var pop := 40
	var p_seed := 7
	var full := false
	var ids: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("pop="):
			pop = int(a.get_slice("=", 1))
		elif a.begins_with("seed="):
			p_seed = int(a.get_slice("=", 1))
		elif a == "check":
			full = true
		else:
			ids.append(a)
	if ids.is_empty():
		ids = ["nordic_mountain", "sahel_town", "rotting_frontier"]
	var bad := 0
	for id in ids:
		var t0 := Time.get_ticks_msec()
		var request := VillagePlace.request(p_seed, pop, id)
		var errors := BuildingLibrary.validate(request)
		if not errors.is_empty():
			print("== %s REFUSED %s" % [id, str(errors)])
			bad += 1
			continue
		var made = BrickWild.generate(request)
		if made == null or not made.is_ok():
			print("== %s DID NOT GENERATE %s" % [id, str(made.errors if made != null else [])])
			bad += 1
			continue
		var plan: VillagePlan = made.village
		var spec: VillageSpec = plan.spec
		var report := VillageVernacularCheck.new().check(VillageVernacularCheck.measure_plan(plan), spec.feature_set())
		var kinds := {}
		var leaning := 0
		for b in plan.buildings:
			var r := b.get("request") as BuildingRequest
			if r == null:
				continue
			kinds[String(r.kind)] = int(kinds.get(String(r.kind), 0)) + 1
			leaning += int(r.jank > 0.0)
		print("== %s '%s': culture %s form %s wealth %.2f upkeep %.2f decoration %.2f water %s enclosure %s purpose %s" % [
			id, spec.feature_set().village_name(p_seed), spec.effective_culture(), spec.form, spec.wealth, spec.upkeep,
			spec.decoration_level, spec.water, spec.enclosure, spec.purpose])
		print("   buildings %s, %d leaning; vernacular check %s in %.1f s" % [str(kinds), leaning,
			"OK" if report["ok"] else "FAILED", (Time.get_ticks_msec() - t0) / 1000.0])
		for why in report["failures"]:
			print("   FAIL %s" % String(why))
		for why in report["warnings"]:
			print("   warn %s" % String(why))
		bad += int(not report["ok"])
		if full:
			var qa: Dictionary = BrickWild.check(made)
			print("   village QA %s (%d failures) at %.1f s" % ["OK" if qa.get("ok", false) else "FAILED",
				(qa.get("failures", []) as Array).size(), (Time.get_ticks_msec() - t0) / 1000.0])
			for why in (qa.get("failures", []) as Array).slice(0, 12):
				print("   QA %s" % str(why))
			bad += int(not qa.get("ok", false))
	quit(1 if bad > 0 else 0)
