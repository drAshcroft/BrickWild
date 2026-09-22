class_name VillageWaterPlanSuite
extends RefCounted

static func run() -> SuiteResult:
	var res := SuiteResult.new("village water plan")
	for seed in range(50):
		for kind in [&"pond", &"stream", &"river", &"coast"]:
			var spec := VillageSpec.new(32000 + seed)
			spec.population = 30
			spec.purpose = &"fishing" if kind == &"coast" else &"farming"
			spec.culture = &"english"
			spec.enclosure = &"hedge"
			spec.water = kind
			spec.generate(spec.seed)
			var site := VillageSitePlanner.site_rect(spec)
			var road := {"points": PackedVector2Array([
				Vector2(site.position.x, site.get_center().y),
				Vector2(site.end.x, site.get_center().y)]), "class": &"through",
				"width": 6.0, "verge": 2.0}
			var common := {"poly": Poly.from_rect(Rect2(
				Vector2(site.get_center().x - 12.0, site.get_center().y - 8.0),
				Vector2(24.0, 16.0))), "kind": &"common"}
			var result := VillageWaterPlan.build(spec, site, [road], [common])
			var water: Array = result["water"]
			if water.size() != 1:
				res.fail("%s/%d: expected one water polygon" % [kind, seed])
				continue
			var poly: PackedVector2Array = water[0]["poly"]
			if poly.size() < 4:
				res.fail("%s/%d: water polygon is degenerate" % [kind, seed])
			for p in poly:
				if not site.grow(0.01).has_point(p):
					res.fail("%s/%d: water escaped site" % [kind, seed])
			if kind in [&"stream", &"river"] and result["crossings"].is_empty():
				res.fail("%s/%d: crossing was not recorded" % [kind, seed])
			if kind == &"pond" and not result["crossings"].is_empty():
				res.fail("pond/%d: pond must clear every road ribbon" % seed)
			res.checked += 1
	# Negative: a road wholly away from water must not invent a bridge.
	var no_cross := VillageSpec.new(32999)
	no_cross.population = 30
	no_cross.water = &"stream"
	no_cross.generate(no_cross.seed)
	var site2 := VillageSitePlanner.site_rect(no_cross)
	var away := {"points": PackedVector2Array([
		Vector2(site2.position.x + 4.0, site2.position.y),
		Vector2(site2.position.x + 4.0, site2.end.y)]), "class": &"lane",
		"width": 3.0, "verge": 1.0}
	var negative := VillageWaterPlan.build(no_cross, site2, [away], [])
	if not negative["crossings"].is_empty():
		res.fail("negative: off-water road invented a crossing")
	res.checked += 1
	return res
