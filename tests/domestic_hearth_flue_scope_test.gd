extends SceneTree
## The style chimney chance remains drawn, then a selected native fireplace
## requires its real flue. Specialist scopes must not inherit that override.

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	_check_case(&"cottage", &"none", &"", true, true)
	_check_case(&"farmhouse", &"none", &"", true, true)
	_check_case(&"thatch_cottage", &"none", &"", true, true)
	_check_case(&"witch_hut", &"none", &"", false, false)
	_check_case(&"farmhouse", &"innkeeper", &"", false, false)
	_check_case(&"farmhouse", &"none", &"fixture_world", false, false)
	_check_case(&"mediterranean", &"none", &"", false, false)
	_check_case(&"pueblo", &"none", &"", false, false)
	for failure in _failures:
		push_error(failure)
	print("domestic flue scope: %d checks, %d failures" % [_checks, _failures.size()])
	quit(1 if not _failures.is_empty() else 0)


func _check_case(style: StringName, trade: StringName, family: StringName,
		should_force: bool, require_host: bool) -> void:
	var spec := HouseSpec.new(7441)
	spec.style = style
	spec.trade = trade
	var plan: HousePlan = HouseGenerator.generate(spec, spec.seed, true, family)
	# Exercise the decision after the original generator chance has been drawn.
	spec.chimney = false
	HousePlanFeatures.choose_hearth(plan, spec)
	var has_host := int(plan.hearth.get("room", -1)) >= 0
	_check(not require_host or has_host,
		"%s/%s/%s fixture did not select its expected hearth host" % [style, trade, family])
	_check(spec.chimney == (should_force and has_host),
		"%s/%s/%s incorrectly resolved chimney=%s for hearth host=%s" % [
			style, trade, family, spec.chimney, has_host])


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
