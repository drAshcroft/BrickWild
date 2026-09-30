extends RefCounted
## CAS-009: compact Rhine ward, slender Bergfried and larger Palas.

static func run() -> SuiteResult:
	var result := SuiteResult.new("castle Bergfried and Palas")
	var forced := _spec(918009, true)
	_check_positive(result, forced, "forced fixture")
	_check_access(result, forced)
	_negative_controls(result, forced)
	for variant in [{"width": 42.0, "sides": 4}, {"width": 42.0, "sides": 6},
			{"width": 50.0, "sides": 4}, {"width": 50.0, "sides": 6},
			{"width": 55.0, "sides": 4}, {"width": 55.0, "sides": 6}]:
		var width: float = variant.width
		var sides: int = variant.sides
		_check_positive(result, _spec(918009, true, width, sides),
			"forced %.0fm/%d sides" % [width, sides])
	var natural_seed := -1
	for seed in range(1, 5000):
		var plan: Dictionary = CastleSpec.plan_for(&"norman", &"castle", seed)
		if plan.kind == &"bergfried":
			natural_seed = seed
			break
	result.checked += 1
	if natural_seed < 0:
		result.fail("no deterministic Norman castle seed selected a Bergfried plan")
	else:
		_check_positive(result, _spec(natural_seed, false), "natural seed %d" % natural_seed)
	if result.checked < 7:
		result.fail("suite executed only %d checks; forced + natural positives and four mutations require at least 7" % result.checked)
	return result


static func _spec(seed: int, forced: bool, width := 46.0, sides := 5) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = width
	spec.length = width
	spec.height = 10.0
	spec.tier_override = &"castle"
	if forced:
		spec.plan_override = &"bergfried"
		spec.sides_override = sides
	CastleGenerator.generate(spec, seed)
	return spec


static func _check_positive(result: SuiteResult, spec: CastleSpec, who: String) -> void:
	var builder := CastleBuilder.new()
	var mesh := builder.build(spec)
	var report: Dictionary = CastleMassingCheck.new().check(spec, builder)
	result.checked += 1
	if spec.plan_kind != &"bergfried" or spec.sides < 4 or spec.sides > 6:
		result.fail("%s: plan kind/sides are %s/%d" % [who, String(spec.plan_kind), spec.sides])
	for failure in report.failures:
		result.fail("%s massing: %s" % [who, failure])
	if mesh == null or mesh.get_surface_count() < 2:
		result.fail("%s: castle shell did not emit its structural surfaces" % who)


static func _check_access(result: SuiteResult, spec: CastleSpec) -> void:
	var builder := CastleBuilder.new()
	var mesh := builder.build(spec)
	var keep: Dictionary = builder._planned_interiors.get("keep", {})
	result.checked += 1
	if keep.is_empty():
		result.fail("forced fixture has no occupied Bergfried plan")
		return
	var physical := CastleQA.forebuilding_report(spec, builder, mesh, keep)
	result.checked += 1
	if not physical.failures.is_empty():
		result.fail("forced fixture raised stair: %s" % [physical.failures])
	var access := CastleQA.lords_walk(spec, builder, mesh)
	result.checked += 1
	if not access.failures.is_empty():
		result.fail("forced fixture gate-to-Bergfried route: %s" % [access.failures])


static func _negative_controls(result: SuiteResult, spec: CastleSpec) -> void:
	var builder := CastleBuilder.new()
	builder.build(spec)
	var rule := CastleMassingCheck.new()
	rule._check_bergfried(spec, builder)
	result.checked += 1
	if not rule.failures.is_empty():
		result.fail("unmutated fixture fails the bergfried rule: %s" % [rule.failures])
	var keep_door: Dictionary = {}
	var keep_door_index := -1
	for index in builder.part_log.size():
		var part: Dictionary = builder.part_log[index]
		if part.get("tag", "") == "keep" and part.get("kind", "") == "door":
			keep_door = part
			keep_door_index = index
			break
	var original_keep: AABB = builder.mass_aabb("keep")
	var original_hall: AABB = builder.mass_aabb("hall")
	var original_door_y: float = Vector3(keep_door.get("pos", Vector3.ZERO)).y if not keep_door.is_empty() else 0.0
	_set_mass(builder, "keep", AABB(original_keep.position,
		Vector3(11.0, original_keep.size.y, original_keep.size.z)))
	rule.failures.clear()
	rule._check_bergfried(spec, builder)
	_expect(result, _has_failure(rule, "keep footprint"), "wide keep negative control escaped the bergfried rule")
	_set_mass(builder, "keep", original_keep)
	_set_mass(builder, "hall", AABB(original_hall.position,
		Vector3(original_hall.size.x, 1.0, original_hall.size.z)))
	rule.failures.clear()
	rule._check_bergfried(spec, builder)
	_expect(result, _has_failure(rule, "Palas volume"), "small Palas negative control escaped the bergfried rule")
	_set_mass(builder, "hall", original_hall)
	var original_corner := builder.mass_aabb("tower_0_corner_0")
	_set_mass(builder, "tower_0_corner_0", AABB(original_corner.position,
		Vector3(original_corner.size.x, original_keep.end.y + 2.0, original_corner.size.z)))
	rule.failures.clear()
	rule._check_bergfried(spec, builder)
	_expect(result, original_corner.size.x > 0.0 \
		and _has_failure(rule, "keep does not top every other mass"),
		"tall corner tower negative control escaped Bergfried dominance")
	_set_mass(builder, "tower_0_corner_0", original_corner)
	_set_mass(builder, "hall", AABB(original_hall.position + Vector3(20.0, 0.0, 0.0),
		original_hall.size))
	rule.failures.clear()
	rule._check_bergfried(spec, builder)
	_expect(result, _has_failure(rule, "outside the inner ward"),
		"shifted Palas negative control escaped polygon containment")
	_set_mass(builder, "hall", original_hall)
	if keep_door_index >= 0:
		builder.part_log.append(keep_door.duplicate(true))
	rule.failures.clear()
	rule._check_bergfried(spec, builder)
	_expect(result, keep_door_index >= 0 and _has_failure(rule, "2 exterior door records"),
		"second keep door negative control escaped the sole-entry rule")
	if keep_door_index >= 0:
		builder.part_log.pop_back()
	if keep_door_index >= 0:
		keep_door["pos"] = Vector3(keep_door["pos"].x, 1.0, keep_door["pos"].z)
		builder.part_log[keep_door_index] = keep_door
	rule.failures.clear()
	rule._check_bergfried(spec, builder)
	var low_door_logged := keep_door_index >= 0 \
		and Vector3(builder.part_log[keep_door_index].pos).y == 1.0
	_expect(result, low_door_logged and _has_failure(rule, "door sill"),
		"low keep door negative control escaped the bergfried rule")
	if keep_door_index >= 0:
		keep_door["pos"] = Vector3(keep_door["pos"].x, original_door_y, keep_door["pos"].z)
		builder.part_log[keep_door_index] = keep_door


static func _set_mass(builder: CastleBuilder, name: String, bounds: AABB) -> void:
	for row in builder.mass_log:
		if row.name == name:
			row.aabb = bounds
			return


static func _expect(result: SuiteResult, valid: bool, message: String) -> void:
	result.checked += 1
	if not valid:
		result.fail(message)


static func _has_failure(rule: CastleMassingCheck, needle: String) -> bool:
	return rule.failures.any(func(message: String) -> bool: return needle in message)
