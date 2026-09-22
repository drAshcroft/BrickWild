class_name VillageEnclosureSuite
extends RefCounted

static func run() -> SuiteResult:
	var res := SuiteResult.new("village enclosure")
	for seed_index in range(50):
		for enclosure in [&"hedge", &"palisade", &"wall"]:
			for water in [&"none", &"stream", &"river", &"pond", &"coast"]:
				var spec := VillageSpec.new(18000 + seed_index * 17 + res.checked)
				spec.population = 90 if enclosure != &"wall" else 180
				spec.purpose = &"garrison" if enclosure == &"wall" else (&"mill" if water in [&"stream", &"river"] else &"farming")
				spec.culture = &"english"
				spec.enclosure = enclosure
				spec.water = water
				spec.wealth = 0.6
				spec.generate(spec.seed)
				var plan := VillageSitePlanner.plan(spec)
				# Site planner owns roads; this focused fixture supplies representative lots
				# so the pure enclosure API can be tested without lot-planner coupling.
				if plan.lots.is_empty():
					var s := plan.site.grow(-18.0)
					plan.lots.append({"poly": Poly.from_rect(Rect2(s.position, Vector2(s.size.x * 0.42, s.size.y * 0.32)))})
					plan.lots.append({"poly": Poly.from_rect(Rect2(Vector2(s.end.x - s.size.x * 0.42, s.position.y), Vector2(s.size.x * 0.42, s.size.y * 0.32)))})
				var derived := VillageEnclosurePlan.build(plan)
				var report := VillageEnclosureCheck.check(plan, derived)
				res.checked += 1
				if not report["ok"]:
					res.fail("seed%d/%s/%s: %s" % [seed_index, enclosure, water, "; ".join(report["failures"])])
				if res.checked % 75 == 0:
					print("VIL018 enclosure progress ", res.checked,
						" failures=", res.failures.size())
	# Negative: a field deliberately inside the offset hull must be rejected.
	var bad := VillageSpec.new(19001)
	bad.population = 90
	bad.purpose = &"farming"
	bad.culture = &"english"
	bad.enclosure = &"hedge"
	bad.generate(bad.seed)
	var bad_plan := VillageSitePlanner.plan(bad)
	var s2 := bad_plan.site.grow(-18.0)
	bad_plan.lots.append({"poly": Poly.from_rect(Rect2(s2.position, Vector2(s2.size.x * 0.5, s2.size.y * 0.4)))})
	bad_plan.fields.append({"poly": Poly.from_rect(Rect2(s2.position + Vector2(5.0, 5.0), Vector2(10, 10))), "kind": &"field"})
	var bad_derived := VillageEnclosurePlan.build(bad_plan)
	bad_derived["fields"] = [{"poly": bad_derived["edge"], "kind": &"field"}]
	var bad_report := VillageEnclosureCheck.check(bad_plan, bad_derived)
	res.checked += 1
	if bad_report["ok"]:
		res.fail("negative fixture: field inside enclosure was accepted")
	# A long road crossing a narrow stream must produce one short crossing mass,
	# never a bridge/ford spanning the entire road segment.
	var crossing := VillageSpec.new(19002)
	crossing.population = 90
	crossing.purpose = &"farming"
	crossing.culture = &"english"
	crossing.generate(crossing.seed)
	var crossing_plan := VillageSitePlanner.plan(crossing)
	crossing_plan.roads.clear()
	crossing_plan.roads.append({"points": PackedVector2Array([Vector2(-100, 0), Vector2(100, 0)]),
		"class": &"through", "width": 6.0, "verge": 2.0, "surface": "road"})
	crossing_plan.water.append({"poly": Poly.from_rect(Rect2(Vector2(-1.5, -20), Vector2(3.0, 40.0))), "kind": &"stream"})
	var crossing_builder := VillageBuilder.new()
	crossing_builder.build(crossing_plan)
	res.checked += 1
	var ford_found := false
	for mass in crossing_builder.mass_log:
		if String(mass["name"]).begins_with("ford"):
			ford_found = true
			if maxf(float(mass["aabb"].size.x), float(mass["aabb"].size.z)) > 14.0:
				res.fail("crossings: ford spans the long road instead of the stream")
	if not ford_found:
		res.fail("crossings: long-road stream fixture emitted no ford")
	return res
