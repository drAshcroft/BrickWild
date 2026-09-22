class_name CastleFormsSuite
extends RefCounted
## Bounded production regression for the tower-house and motte shell forms.
## Each fixture goes through CastleBuilder.build(), then the strict physical
## interior walk contract checks the emitted door, approach chain, and stairs.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle forms")
	_check(res, _tower(), "tower_house")
	_check(res, _motte(), "keep_shell")
	return res


static func _check(res: SuiteResult, spec: CastleSpec, id: String) -> void:
	var builder := CastleBuilder.new()
	var mesh := builder.build(spec)
	var report: Dictionary = CastleQA.lords_walk(spec, builder, mesh)
	_want(res, bool(report.get("applicable", false)), id + ": strict form QA was not applicable")
	_want(res, report.failures.is_empty(), id + ": strict form QA failed: " + str(report.failures))
	var door: Dictionary = report.get("door", {})
	_want(res, bool(door.get("matched", false)) and bool(door.get("clear", false)),
		id + ": authored door was not matched and clear")
	var approach: Dictionary = report.get("approach", {})
	_want(res, int(approach.get("steps", 0)) > 0
		and bool(approach.get("contiguous", false))
		and bool(approach.get("monotonic", false))
		and bool(approach.get("walkable_risers", true)),
		id + ": approach chain is incomplete")
	var stairs: Dictionary = report.get("stairs", {})
	_want(res, int(stairs.get("actual", -1)) == int(stairs.get("expected", -2))
		and stairs.get("failures", []).is_empty(), id + ": stair chain is incomplete")


static func _tower() -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"wizard"
	spec.width = 9.0
	spec.length = 9.0
	spec.height = 45.0
	spec.tier_override = &"house"
	spec.plan_override = &"tower_house"
	CastleGenerator.generate(spec, 8803)
	return spec


static func _motte() -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 90.0
	spec.length = 110.0
	spec.height = 12.0
	spec.tier_override = &"castle"
	spec.plan_override = &"motte_bailey"
	CastleGenerator.generate(spec, 8806)
	return spec


static func _want(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
