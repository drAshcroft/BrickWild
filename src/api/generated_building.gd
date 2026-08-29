class_name GeneratedBuilding
extends RefCounted
## The engine-native representation produced by BigGlade.generate().
##
## `spec` remains family-specific. Houses, shops, and hotels additionally retain
## their HousePlan, because the plan -- not the shell mesh -- is their representation.

var request: BuildingRequest
var spec: RefCounted
var plan: HousePlan
var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []


func is_ok() -> bool:
	if not errors.is_empty() or request == null or spec == null:
		return false
	if spec is HouseSpec:
		return plan != null and plan.spec == spec
	return plan == null


func representation() -> RefCounted:
	if plan != null:
		return plan
	return spec


func name() -> String:
	if spec == null:
		return ""
	return str(spec.get("variant_name"))
