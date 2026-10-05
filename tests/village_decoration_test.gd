extends RefCounted
## Native quality controls for outdoor village dressing. No new class_name is
## needed; the ordered runner can preload this focused fixture.

static func run() -> SuiteResult:
	var res := SuiteResult.new("vdecoration")
	var spec := VillageSpec.new(9217)
	spec.population = 30
	spec.culture = &"english"
	spec.purpose = &"farming"
	spec.wealth = 0.4
	spec.enclosure = &"hedge"
	spec.generate(9217)
	var base: VillagePlan = VillageLotPlanner.plan(spec)
	if base.buildings.is_empty():
		res.fail("fixture village did not place buildings")
		return res

	var default_redressed := _redressed(base, 0.5, 1.0)
	res.checked += 1
	if not _array_equal(base.props, default_redressed.props) or not _array_equal(base.plants, default_redressed.plants):
		res.fail("default decoration/upkeep changed historical dressing")

	var plain := _redressed(base, 0.0, 1.0)
	var lush := _redressed(base, 1.0, 1.0)
	var plain_repeat := _redressed(base, 0.0, 1.0)
	var lush_repeat := _redressed(base, 1.0, 1.0)
	var weathered := _redressed(base, 0.5, 0.0)
	res.checked += 4
	if not _array_equal(plain.props, plain_repeat.props) or not _array_equal(plain.plants, plain_repeat.plants):
		res.fail("decoration level zero is not deterministic")
	if not _array_equal(lush.props, lush_repeat.props) or not _array_equal(lush.plants, lush_repeat.plants):
		res.fail("decoration level one is not deterministic")
	if plain.plants.size() >= base.plants.size():
		res.fail("decoration level zero did not remove optional greenery")
	if lush.plants.size() <= base.plants.size():
		res.fail("decoration level one did not add measured lush planting")
	if not _same_layout(base, plain) or not _same_layout(base, lush):
		res.fail("decoration changed roads, lots, buildings, fields or enclosure")
	if not _same_layout(base, weathered) or not is_equal_approx(weathered.spec.wealth, base.spec.wealth):
		res.fail("upkeep changed village layout or wealth")
	if plain.equals(base) or lush.equals(base):
		res.fail("VillagePlan equality ignored decoration controls")
	for variant in [plain, lush]:
		res.checked += 1
		var report: Dictionary = VillageQA.new().check(variant, {}, false)
		for failure in report["failures"]:
			res.fail("decoration %.1f QA: %s" % [variant.spec.decoration_level, failure])
		if int(report["stats"].get("green_trees", 0)) > VillageDressCheck.GREEN_TREES_MAX:
			res.fail("decoration level %.1f exceeds the common tree cap" % variant.spec.decoration_level)
		if not _has_prop(variant, "well"):
			res.fail("decoration level %.1f removed the functional village well" % variant.spec.decoration_level)
		if not variant.plants.any(func(plant: Dictionary) -> bool: return plant.get("zone", &"") == &"enclosure"):
			res.fail("decoration level %.1f removed functional enclosure planting" % variant.spec.decoration_level)

	# Lower upkeep leaves more storm-broken trees in the village's wild edge
	# palette. Sample deterministic positions directly; no extra planning pass.
	var base_ctx := VillageDressContext.make_context(base)
	var weather_ctx := VillageDressContext.make_context(weathered)
	var edge_keys := VillageDressRules.palette_keys(base_ctx, "edge")
	var cared_dead := 0
	var weathered_dead := 0
	if not edge_keys.is_empty():
		for x in range(-20, 21):
			for z in range(-20, 21):
				var at := Vector2(float(x) * 3.17, float(z) * 2.71)
				var cared := VillageDressRules._edge_kind(base, base_ctx, edge_keys[0], at)
				var worn := VillageDressRules._edge_kind(weathered, weather_ctx, edge_keys[0], at)
				if PropCatalog.category(cared) == "dead_tree": cared_dead += 1
				if PropCatalog.category(worn) == "dead_tree": weathered_dead += 1
		res.checked += 1
		if weathered_dead <= cared_dead:
			res.fail("low upkeep did not increase dead-edge vegetation")
	else:
		res.fail("culture fixture has no edge palette for the upkeep control")

	var bad_clearance := _redressed(base, 0.0, 1.0)
	var bad_door: Vector2 = VillageMeasure.door(bad_clearance.buildings[0])
	var known_cover := VillageDressRules.palette_keys(VillageDressContext.make_context(bad_clearance), "ground")
	if not known_cover.is_empty():
		bad_clearance.plants.append({"key": known_cover[0], "pos": bad_door,
			"canopy": 0.0, "trunk": 0.0})
		var broken_report: Dictionary = VillageDressCheck.new().check(bad_clearance)
		res.checked += 1
		var caught := false
		for failure in broken_report["failures"]:
			caught = caught or String(failure).begins_with("doorways:")
		if not caught:
			res.fail("VillageDressCheck did not reject a deliberately blocked doorway")
	else:
		res.fail("culture fixture has no measured ground plant for clearance negative control")

	var compact_spec := VillageSpec.compact(33018, 12, &"english", &"market")
	var compact_base: VillagePlan = VillageLotPlanner.plan(compact_spec)
	var compact_zero := _redressed(compact_base, 0.0, 1.0)
	var compact_lush := _redressed(compact_base, 1.0, 1.0)
	res.checked += 1
	if not _same_layout(compact_base, compact_zero) or not _same_layout(compact_base, compact_lush):
		res.fail("decoration changed compact roads, lots or building requests")
	for variant in [compact_zero, compact_lush]:
		res.checked += 1
		var report: Dictionary = VillageQA.new().check(variant, {}, false)
		for failure in report["failures"]:
			res.fail("compact decoration QA: %s" % failure)

	var invalid := VillageSpec.new(1)
	invalid.decoration_level = NAN
	invalid.upkeep = INF
	res.checked += 1
	if invalid.errors().size() < 2:
		res.fail("native controls accepted non-finite values")
	var out_of_range := VillageSpec.new(1)
	out_of_range.decoration_level = 1.1
	out_of_range.upkeep = -0.1
	res.checked += 1
	if out_of_range.errors().size() < 2:
		res.fail("native controls accepted values outside [0, 1]")

	return res


static func _redressed(source: VillagePlan, level: float, upkeep_value: float) -> VillagePlan:
	var spec := _copy_spec(source.spec)
	spec.decoration_level = level
	spec.upkeep = upkeep_value
	var out := VillagePlan.new(spec)
	out.site = source.site
	out.landmark_site = source.landmark_site.duplicate(true)
	out.roads = source.roads.duplicate(true)
	out.lots = source.lots.duplicate(true)
	out.buildings = source.buildings.duplicate(true)
	out.commons = source.commons.duplicate(true)
	out.enclosure = source.enclosure.duplicate()
	out.enclosure_kept_fraction = source.enclosure_kept_fraction
	out.gate_crossings = source.gate_crossings.duplicate(true)
	out.water = source.water.duplicate(true)
	out.water_crossings = source.water_crossings.duplicate(true)
	out.fields = source.fields.duplicate(true)
	return VillageDresser.dress(out)


static func _copy_spec(source: VillageSpec) -> VillageSpec:
	var spec := VillageSpec.new(source.seed)
	spec.compact_display = source.compact_display
	spec.population = source.population
	spec.culture = source.culture
	spec.purpose = source.purpose
	spec.wealth = source.wealth
	spec.enclosure = source.enclosure
	spec.water = source.water
	spec.orientation = source.orientation
	spec.period = source.period
	spec.site_brief = source.site_brief
	spec.regime = source.regime
	spec.tongue = source.tongue
	spec.source_culture = source.source_culture
	spec.plant_palette = source.plant_palette
	spec.kept_buildings = source.kept_buildings.duplicate(true)
	spec.enclosure_kept_fraction = source.enclosure_kept_fraction
	spec.terrain_envelope = source.terrain_envelope.duplicate(true)
	spec.requested_site_m = source.requested_site_m
	spec.decoration_level = source.decoration_level
	spec.upkeep = source.upkeep
	spec.generate(source.seed)
	return spec


static func _same_layout(a: VillagePlan, b: VillagePlan) -> bool:
	return a.site == b.site and VillagePlan._value_equal(a.roads, b.roads) \
		and VillagePlan._value_equal(a.lots, b.lots) \
		and VillagePlan._value_equal(a.buildings, b.buildings) \
		and VillagePlan._value_equal(a.commons, b.commons) \
		and VillagePlan._value_equal(a.enclosure, b.enclosure) \
		and VillagePlan._value_equal(a.fields, b.fields)


static func _array_equal(a: Array, b: Array) -> bool:
	return VillagePlan._array_of_dict_equal(a, b)


static func _has_prop(plan: VillagePlan, key: String) -> bool:
	for prop in plan.props:
		if String(prop.get("key", "")).to_lower().contains(key):
			return true
	return false
